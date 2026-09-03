CREATE TABLE IF NOT EXISTS categories (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_categories_name (name)
);

CREATE TABLE IF NOT EXISTS products (
  id VARCHAR(64) PRIMARY KEY,
  name VARCHAR(160) NOT NULL,
  sku VARCHAR(80) NOT NULL,
  barcode VARCHAR(120) NULL UNIQUE,
  category VARCHAR(100) NOT NULL,
  price DECIMAL(12,2) NOT NULL DEFAULT 0,
  stock INT NOT NULL DEFAULT 0,
  minimum_stock INT NOT NULL DEFAULT 0,
  image_url TEXT NULL,
  image_public_id VARCHAR(255) NULL,
  model_url TEXT NULL,
  model_public_id VARCHAR(255) NULL,
  render_url TEXT NULL,
  render_public_id VARCHAR(255) NULL,
  model_built_at TIMESTAMP NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_products_name (name),
  INDEX idx_products_sku (sku),
  INDEX idx_products_category (category)
);

CREATE TABLE IF NOT EXISTS product_images (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id VARCHAR(64) NOT NULL,
  view_index TINYINT UNSIGNED NOT NULL,
  image_url TEXT NOT NULL,
  image_public_id VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_product_image_product FOREIGN KEY (product_id)
    REFERENCES products(id) ON DELETE CASCADE,
  UNIQUE KEY uq_product_view (product_id, view_index)
);

CREATE TABLE IF NOT EXISTS stock_movements (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id VARCHAR(64) NOT NULL,
  type ENUM('incoming', 'outgoing') NOT NULL,
  quantity INT UNSIGNED NOT NULL,
  note VARCHAR(255) NOT NULL DEFAULT '',
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_movement_product FOREIGN KEY (product_id)
    REFERENCES products(id) ON DELETE CASCADE,
  INDEX idx_movements_product_date (product_id, created_at)
);
