# From https://medium.com/@weidagang/demystifying-the-attention-formula-8f5ad602546f

import numpy as np
import matplotlib.pyplot as plt

def attention(query, key, value):
  """
  Computes the attention output.

  Args:
    query: Query vector or matrix (num_queries, d_k).
    key: Key matrix (sequence_length, d_k).
    value: Value matrix (sequence_length, d_v).

  Returns:
    Attention output matrix (num_queries, d_v).
  """
  d_k = key.shape[-1]
  scores = np.matmul(query, key.T) / np.sqrt(d_k)
  attention_weights = softmax(scores)
  output = np.matmul(attention_weights, value)
  return output, attention_weights

def softmax(x):
  """Compute softmax values for each sets of scores in x."""
  e_x = np.exp(x - np.max(x, axis=-1, keepdims=True))
  return e_x / e_x.sum(axis=-1, keepdims=True)

# Example usage (using the 2D example from above)
query = np.array([[2, 3]])
key = np.array([[1, 2], [3, 1], [0, 4]])
value = np.array([[5, 6], [7, 8], [9, 10]])

output, attention_weights = attention(query, key, value)
print(f"Attention output: {output}")

# Visualization
fig, ax = plt.subplots()

# Plot keys and values
ax.scatter(key[:, 0], key[:, 1], s=100, c='blue', label='Keys')
for i in range(len(key)):
    ax.text(key[i, 0], key[i, 1], f'  K{i+1}', color='blue')

ax.scatter(value[:, 0], value[:, 1], s=100, c='red', label='Values')
for i in range(len(value)):
    ax.text(value[i, 0], value[i, 1], f'  V{i+1}', color='red')

# Plot query
ax.scatter(query[:, 0], query[:, 1], s=100, c='green', label='Query')
ax.text(query[0, 0], query[0, 1], '  Q', color='green')

# Plot attention output
ax.scatter(output[:, 0], output[:, 1], s=100, c='purple', label='Output')
ax.text(output[0, 0], output[0, 1], '  Output', color='purple')

# Draw lines showing attention weights
for i in range(len(key)):
    weight = attention_weights[0, i]
    if weight > 0.01 :
      ax.plot([query[0, 0], key[i, 0]], [query[0, 1], key[i, 1]],
              linestyle='--', color='gray', alpha=min(weight * 3, 1))

ax.set_xlabel('Dimension 1')
ax.set_ylabel('Dimension 2')
ax.set_title('Attention Mechanism Visualization')
ax.legend()
ax.grid(True)
plt.show()
