import { Injectable } from '@angular/core';
import {HttpClient} from '@angular/common/http';
import {Observable} from 'rxjs';

export interface User {
  id?: number;
  name: string;
  email: string;
  created_at?: string;
}

@Injectable({
  providedIn: 'root'
})
export class UserService {
  private apiUrl: string;

  constructor(private http: HttpClient) {
    // Get base URL from window location or fallback
    const protocol = window.location.protocol;
    const host = window.location.host;
    const apiHost = this.getApiHost();
    this.apiUrl = `${protocol}//${apiHost}/api/users`;
  }

  private getApiHost(): string {
    // In production, ALB DNS is injected via window.API_HOST
    if (typeof (window as any).API_HOST !== 'undefined') {
      return (window as any).API_HOST;
    }
    // Fallback to localhost for development
    return 'localhost:3000';
  }

  getUsers(): Observable<User[]> {
    return this.http.get<User[]>(this.apiUrl);
  }

  addUser(user: User): Observable<User> {
    return this.http.post<User>(this.apiUrl, user);
  }

  updateUser(user: User): Observable<User> {
    return this.http.put<User>(`${this.apiUrl}/${user.id}`, user);
  }

  deleteUser(id: number | undefined): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }
}
