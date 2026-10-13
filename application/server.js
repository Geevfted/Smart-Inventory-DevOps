const express = require('express');
const pool = require('./src/db'); // Import the database connection pool

const app = express();
const port = process.env.PORT || 3000;


app.use(express.json());

app.get('/', (req, res) => {
  res.send('Smart Inventory API is running');
});

app.get('/health', async (req, res) => {

  try {
    await pool.query('SELECT 1')

        res.status(200).json({ status: 'ok', database: 'connected' });
  }
    catch (error) {
    res.status(503).json({ status: 'error', database: 'disconnected', message: error.message });
  }
});

app.get('/products', async (req, res) => {

  const { search, low_stock, page = 1, limit = 10 } = req.query;

  const offset = (page - 1) * limit;

  try {
    let query = 'SELECT * FROM products WHERE 1=1';
    const values = [];

    if (search) {
      values.push(`%${search}%`);
      query += ` AND (name ILIKE $${values.length} OR sku ILIKE $${values.length})`;
    }

    if (low_stock === 'true') {
      query += ' AND quantity <= low_stock_threshold';
    }

    query += ` ORDER BY id ASC LIMIT $${values.length + 1} OFFSET $${values.length + 2}`;

    values.push(Number(limit), Number(offset));

    const result = await pool.query(query, values);

    res.json(result.rows);

  } catch (error) {
    console.error('Database error:', error.message);
    res.status(500).json({ error: 'failed to fetch products' });
  }
});

app.post('/products', async (req, res) => {
  const { name, sku, quantity, price, low_stock_threshold } = req.body;

 const errors = [];

  if (!name) errors.push('Missing required field: name');

  if (!sku) errors.push('Missing required field: sku');

  if (quantity === undefined) {errors.push('Missing required field: quantity');

  } else if (typeof quantity !== 'number') {errors.push('Quantity must be a number');

  } else if (quantity < 0) {errors.push('Quantity cannot be negative');

  }

  if (price === undefined) {errors.push('Missing required field: price');

  } else if (typeof price !== 'number') {errors.push('Price must be a number');

  } else if (price < 0) {errors.push('Price cannot be negative');

  }

  if (low_stock_threshold === undefined) {errors.push('Missing required field: low_stock_threshold');

  } else if (typeof low_stock_threshold !== 'number') {errors.push('Low stock threshold must be a number');

  } else if (low_stock_threshold < 0) {errors.push('Low stock threshold cannot be negative');

  }

  if (errors.length > 0) {
    return res.status(400).json({ error: errors.join(', ') });
  }

  try {
    const result = await pool.query(
      'INSERT INTO products (name, sku, quantity, price, low_stock_threshold) VALUES ($1, $2, $3, $4, $5) RETURNING *',
      [name, sku, quantity, price, low_stock_threshold]
    );
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Database error:', error.message);

    if (error.code === '23505') { // Unique violation error code
      return res.status(409).json({ error: 'SKU already exists' });
    }

    res.status(500).json({ error: 'failed to create product' });
  }
});

app.post('/products/:id/stock-in', async (req, res) => {
  const { id } = req.params;
  const { movement_type, quantity, note } = req.body;

  if (quantity === undefined || quantity <= 0 ) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Update the product quantity
    const result = await client.query(
      'UPDATE products SET quantity = quantity + $1 WHERE id = $2 RETURNING *',
      [quantity, id]
    );

    if (result.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Product not found' });
    }

    // Insert a record into stock_movements table
    await client.query(
      'INSERT INTO stock_movements (product_id, movement_type, quantity, note) VALUES ($1, $2, $3, $4)',
      [id, movement_type || 'stock-in', quantity, note || null]
    );

    await client.query('COMMIT');

    res.json(result.rows[0]);   b
  }

  catch (error) {
    await client.query('ROLLBACK');

    console.error('Database error:', error.message);

    res.status(500).json({ error: 'failed to add stock' });
  }
  finally {
    client.release();
  }
});

app.post('/products/:id/stock-out', async (req, res) => {
  const { id } = req.params;
  const { movement_type, quantity, note } = req.body;

  if (quantity === undefined || quantity <= 0) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  const client = await pool.connect();

  try {
    await client.query('BEGIN');

    // Check if the product exists and has enough stock
    const productResult = await client.query('SELECT * FROM products WHERE id = $1', [id]);
    if (productResult.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }

    if (productResult.rows[0].quantity < quantity) {
      await client.query('ROLLBACK');
      return res.status(400).json({ error: 'Insufficient stock' });
    }

    // Update the product quantity
    const result = await client.query(
      'UPDATE products SET quantity = quantity - $1 WHERE id = $2 RETURNING *',
      [quantity, id]
    );

    // Insert a record into stock_movements table
    await client.query(
      'INSERT INTO stock_movements (product_id, movement_type, quantity, note) VALUES ($1, $2, $3, $4)',
      [id, movement_type || 'stock-out', quantity, note || null]
    );

    await client.query('COMMIT');

    res.json(result.rows[0]);
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('Database error:', error.message);
    res.status(500).json({ error: 'failed to update product quantity' });
  }
  finally {
    client.release();
  }
});

app.get('/products/low-stock', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM products WHERE quantity <= low_stock_threshold');
    res.json(result.rows);
  } catch (error) {
    console.error('Database error:', error.message);
    res.status(500).json({ error: 'failed to fetch low stock products' });
  }
});

app.get('/products/:id/movements', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('SELECT * FROM stock_movements WHERE product_id = $1 ORDER BY created_at DESC', [id]);
    res.json(result.rows);
  } catch (error) {
    console.error('Database error:', error.message);
    res.status(500).json({ error: 'failed to fetch stock movements' });
  }
});


app.get('/products/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('SELECT * FROM products WHERE id = $1', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('Database error:', error.message);
    res.status(500).json({ error: 'failed to fetch product' });
  }
});

app.put('/products/:id', async (req, res) => {
  const { id } = req.params;
  const { name, sku, quantity, price, low_stock_threshold } = req.body;

  const errors = [];

  if (name !== undefined) {
    if (typeof name !== 'string') {
      errors.push('Name must be a string');
    } else if (name.trim() === '') {
      errors.push('Name cannot be empty');
    }
  }

  if (sku !== undefined) {
    if (typeof sku !== 'string') {
      errors.push('SKU must be a string');
    } else if (sku.trim() === '') {
      errors.push('SKU cannot be empty');
    }
  }

  if (quantity !== undefined) {
    if (typeof quantity !== 'number') {
      errors.push('Quantity must be a number');
    } else if (quantity < 0) {
      errors.push('Quantity cannot be negative');
    }
  }

  if (price !== undefined) {
    if (typeof price !== 'number') {
      errors.push('Price must be a number');
    } else if (price < 0) {
      errors.push('Price cannot be negative');
    }
  }

  if (low_stock_threshold !== undefined) {
    if (typeof low_stock_threshold !== 'number') {
      errors.push('Low stock threshold must be a number');
    } else if (low_stock_threshold < 0) {
      errors.push('Low stock threshold cannot be negative');
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({
      error: errors.join(', ')
    });
  }

  try {
    const result = await pool.query(
      `UPDATE products
       SET
         name = COALESCE($1, name),
         sku = COALESCE($2, sku),
         quantity = COALESCE($3, quantity),
         price = COALESCE($4, price),
         low_stock_threshold = COALESCE($5, low_stock_threshold),
         updated_at = CURRENT_TIMESTAMP
       WHERE id = $6
       RETURNING *`,
      [name, sku, quantity, price, low_stock_threshold, id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: 'Product not found'
      });
    }

    res.json(result.rows[0]);

  } catch (error) {
    console.error('Database error:', error.message);

    if (error.code === '23505') {
      return res.status(409).json({
        error: 'SKU already exists'
      });
    }

    res.status(500).json({
      error: 'failed to update product'
    });
  }
});

app.delete('/products/:id', async (req, res) => {
  const { id } = req.params;
  try {
    const result = await pool.query('DELETE FROM products WHERE id = $1 RETURNING *', [id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.json({ message: 'Product deleted successfully' });
  } catch (error) {
    console.error('Database error:', error.message);
    res.status(500).json({ error: 'failed to delete product' });
  }
});









app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
