import os
from django.shortcuts import render, redirect
from django.db import connection, DatabaseError
from django.views.decorators.csrf import csrf_exempt
from django.conf import settings


@csrf_exempt
def login_view(request):
    """
    Stage 1: Intentionally vulnerable SQL Injection Login endpoint.
    Vulnerability: Direct string formatting into raw SQL query without parameterization.
    """
    if request.method == 'GET':
        if request.session.get('user_id'):
            return redirect('dashboard')
        return render(request, 'login.html')

    username = request.POST.get('username', '').strip()
    password = request.POST.get('password', '').strip()

    if not username:
        return render(request, 'login.html', {
            'error': 'Please enter a username.',
            'username': username
        })

    # INTENTIONALLY VULNERABLE RAW SQL QUERY
    query = f"SELECT id, username, role FROM app_users WHERE username = '{username}' AND password = '{password}'"

    try:
        with connection.cursor() as cursor:
            cursor.execute(query)
            user = cursor.fetchone()

        if user:
            # Login successful: store user details in session
            request.session['user_id'] = user[0]
            request.session['username'] = user[1]
            request.session['role'] = user[2]
            return redirect('dashboard')
        else:
            return render(request, 'login.html', {
                'error': 'Invalid username or password.',
                'username': username,
                'executed_query': query if settings.DEBUG else None
            })

    except DatabaseError as e:
        # Display verbose database error for educational / debugging purposes
        return render(request, 'login.html', {
            'error': f"Database Error: {str(e)}",
            'username': username,
            'executed_query': query if settings.DEBUG else None
        })
    except Exception as e:
        return render(request, 'login.html', {
            'error': f"Unexpected Error: {str(e)}",
            'username': username
        })


def dashboard_view(request):
    """
    Post-authentication dashboard displaying Stage 1 Web Flag and navigation.
    """
    if not request.session.get('user_id'):
        return redirect('login')

    username = request.session.get('username', 'User')
    role = request.session.get('role', 'user')

    # Retrieve Stage 1 Web Flag from database or fallback to file
    flag_value = "FLAG{SQLI_LOGIN_BYPASS}"
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT flag_value FROM challenge_flags WHERE stage = 'web_login' LIMIT 1")
            row = cursor.fetchone()
            if row:
                flag_value = row[0]
    except Exception:
        # Fallback to flag file if database query fails
        flag_file = os.path.join(settings.BASE_DIR.parent, 'flags', 'web.flag')
        if os.path.exists(flag_file):
            with open(flag_file, 'r') as f:
                flag_value = f.read().strip()

    context = {
        'username': username,
        'role': role,
        'web_flag': flag_value,
    }
    return render(request, 'dashboard.html', context)


def logout_view(request):
    """Logs out the user and clears session data."""
    request.session.flush()
    return redirect('login')
