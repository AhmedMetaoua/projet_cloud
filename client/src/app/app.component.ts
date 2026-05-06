import { Component } from '@angular/core';
import {User} from './services/user.service';

@Component({
  selector: 'app-root',
  templateUrl: './app.component.html',
  standalone: false,
  styleUrl: './app.component.css'
})
export class AppComponent {
  // title = 'Angular Node MySQL App';
  userToEdit: User | null = null;
  currentYear = new Date().getFullYear();

  handleEditUser(user: User): void {
    this.userToEdit = user;
    // Scroll to the form
    setTimeout(() => {
      document.querySelector('.user-form-container')?.scrollIntoView({
        behavior: 'smooth',
        block: 'center'
      });
    }, 100);
  }

  handleUserSaved(): void {
    this.userToEdit = null;
    // Refresh the user list
    document.dispatchEvent(new CustomEvent('refreshUsers'));
  }

  handleCancelEdit(): void {
    this.userToEdit = null;
  }
}
