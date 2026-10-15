from django.shortcuts import render, redirect
from django.db import connection, DatabaseError
from django.conf import settings


def products_view(request):
    """
    Stage 2: Product Catalog with intentionally vulnerable SQL Injection.
    Vulnerability: The 'category' GET parameter is interpolated directly into
    the raw SQL SELECT query without sanitization or parameter binding.
    """
    if not request.session.get('user_id'):
        return redirect('login')

    categories = []
    products_list = []
    db_error = None
    executed_query = None
    selected_category = request.GET.get('category', '').strip()

    # 1. Fetch Categories for Navigation
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id, name, description FROM categories ORDER BY id ASC")
            categories = [
                {'id': row[0], 'name': row[1], 'description': row[2]}
                for row in cursor.fetchall()
            ]
    except Exception as e:
        db_error = f"Failed to load categories: {str(e)}"

    # 2. Build and Execute Product Query
    if selected_category:
        # INTENTIONALLY VULNERABLE RAW SQL QUERY
        query = f"SELECT id, name, description, price, category_id FROM products WHERE category_id = {selected_category}"
    else:
        query = "SELECT id, name, description, price, category_id FROM products ORDER BY id ASC"

    executed_query = query

    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
            rows = cursor.fetchall()
            for r in rows:
                products_list.append({
                    'id': r[0],
                    'name': r[1],
                    'description': r[2],
                    'price': r[3],
                    'category_id': r[4] if len(r) > 4 else None,
                })
    except DatabaseError as e:
        # Intentionally expose database error for debugging and SQL injection enumeration
        db_error = f"Database Query Error: {str(e)}"
    except Exception as e:
        db_error = f"Application Error: {str(e)}"

    context = {
        'username': request.session.get('username', 'User'),
        'categories': categories,
        'products': products_list,
        'selected_category': selected_category,
        'db_error': db_error,
        'executed_query': executed_query if settings.DEBUG else None,
    }
    return render(request, 'products.html', context)
