"""
URL configuration for CyberLab project.
"""
from django.urls import path, include
from django.shortcuts import redirect

urlpatterns = [
    path('', lambda request: redirect('login'), name='root'),
    path('', include('accounts.urls')),
    path('', include('products.urls')),
]
