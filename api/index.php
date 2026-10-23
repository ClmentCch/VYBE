<?php
// VYBE API : routes JSON sous /api/index.php?action=...
// Les requêtes utilisent PDO avec paramètres liés (pas d'injection SQL).
declare(strict_types=1);

$configFile = __DIR__ . '/config.local.php';
require (file_exists($configFile) ? $configFile : __DIR__ . '/config.php');

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

function respond(int $code, array $data): void {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE);
    exit;
}

function db(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=utf8mb4',
            DB_USER,
            DB_PASS,
            [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_EMULATE_PREPARES => false]
        );
    }
    return $pdo;
}

function bearer(): ?string {
    $h = $_SERVER['HTTP_AUTHORIZATION'] ?? '';
    return preg_match('/^Bearer\s+([a-f0-9]{64})$/i', $h, $m) ? strtolower($m[1]) : null;
}

function currentUserId(): int {
    $token = bearer();
    if ($token === null) respond(401, ['error' => 'unauthorized']);
    $stmt = db()->prepare('SELECT user_id FROM tokens WHERE token = ? AND expires_at > NOW()');
    $stmt->execute([$token]);
    $id = $stmt->fetchColumn();
    if ($id === false) respond(401, ['error' => 'unauthorized']);
    return (int)$id;
}

function body(): array {
    $data = json_decode(file_get_contents('php://input') ?: '', true);
    return is_array($data) ? $data : [];
}

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'register': {
        $b = body();
        $user = trim((string)($b['username'] ?? ''));
        $pass = (string)($b['password'] ?? '');
        if (!preg_match('/^[A-Za-z0-9_]{3,32}$/', $user) || strlen($pass) < 8) {
            respond(400, ['error' => 'invalid username or password (min 8 chars)']);
        }
        try {
            $stmt = db()->prepare('INSERT INTO users (username, password_hash) VALUES (?, ?)');
            $stmt->execute([$user, password_hash($pass, PASSWORD_DEFAULT)]);
        } catch (PDOException $e) {
            respond(409, ['error' => 'username already exists']);
        }
        respond(201, ['ok' => true]);
    }

    case 'login': {
        $b = body();
        $stmt = db()->prepare('SELECT id, password_hash FROM users WHERE username = ?');
        $stmt->execute([trim((string)($b['username'] ?? ''))]);
        $row = $stmt->fetch();
        if (!$row || !password_verify((string)($b['password'] ?? ''), $row['password_hash'])) {
            respond(401, ['error' => 'bad credentials']);
        }
        $token = bin2hex(random_bytes(32));
        $stmt = db()->prepare('INSERT INTO tokens (token, user_id, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))');
        $stmt->execute([$token, $row['id'], TOKEN_TTL_SECONDS]);
        respond(200, ['token' => $token]);
    }

    case 'games': { // liste de mes jeux
        $uid = currentUserId();
        $stmt = db()->prepare('SELECT id, title, published, updated_at FROM games WHERE owner_id = ? ORDER BY updated_at DESC');
        $stmt->execute([$uid]);
        respond(200, ['games' => $stmt->fetchAll()]);
    }

    case 'save': { // créer ou mettre à jour un jeu (JSON de scène Studio)
        $uid = currentUserId();
        $b = body();
        $id = (int)($b['id'] ?? 0);
        $title = substr(trim((string)($b['title'] ?? 'Sans titre')), 0, 120);
        $content = (string)($b['content'] ?? '');
        if (strlen($content) > 5 * 1024 * 1024) respond(413, ['error' => 'game too large']);
        if ($id > 0) {
            $stmt = db()->prepare('UPDATE games SET title = ?, content = ? WHERE id = ? AND owner_id = ?');
            $stmt->execute([$title, $content, $id, $uid]);
            if ($stmt->rowCount() === 0) respond(404, ['error' => 'not found']);
        } else {
            $stmt = db()->prepare('INSERT INTO games (owner_id, title, content) VALUES (?, ?, ?)');
            $stmt->execute([$uid, $title, $content]);
            $id = (int)db()->lastInsertId();
        }
        respond(200, ['id' => $id]);
    }

    case 'publish': { // met le jeu en ligne (visible dans l'app)
        $uid = currentUserId();
        $b = body();
        $stmt = db()->prepare('UPDATE games SET published = ? WHERE id = ? AND owner_id = ?');
        $stmt->execute([!empty($b['published']) ? 1 : 0, (int)($b['id'] ?? 0), $uid]);
        respond(200, ['ok' => true]);
    }

    case 'catalog': { // jeux publiés, visibles par tous les joueurs
        $stmt = db()->query('SELECT g.id, g.title, u.username AS author FROM games g JOIN users u ON u.id = g.owner_id WHERE g.published = 1 ORDER BY g.updated_at DESC LIMIT 100');
        respond(200, ['games' => $stmt->fetchAll()]);
    }

    case 'play': { // contenu d'un jeu publié
        $stmt = db()->prepare('SELECT id, title, content FROM games WHERE id = ? AND published = 1');
        $stmt->execute([(int)($_GET['id'] ?? 0)]);
        $row = $stmt->fetch();
        if (!$row) respond(404, ['error' => 'not found']);
        respond(200, $row);
    }

    default:
        respond(404, ['error' => 'unknown action']);
}
