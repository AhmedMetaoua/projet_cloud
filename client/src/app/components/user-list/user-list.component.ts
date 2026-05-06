import {Component, EventEmitter, OnDestroy, OnInit, Output} from '@angular/core';
import {User, UserService} from '../../services/user.service';

@Component({
  selector: 'app-user-list',
  standalone: false,
  templateUrl: './user-list.component.html',
  styleUrl: './user-list.component.css'
})
export class UserListComponent implements OnInit, OnDestroy {
  @Output() editUser = new EventEmitter<User>();

  users: User[] = [];
  loading = false;
  error: string | null = null;
  deleteLoading: number | undefined = undefined;
  private refreshListener: any;

  constructor(private userService: UserService) { }

  ngOnInit(): void {
    this.loadUsers();
    // Listen for refresh events
    this.refreshListener = () => this.loadUsers();
    document.addEventListener('refreshUsers', this.refreshListener);
  }

  ngOnDestroy(): void {
    // Clean up event listener
    document.removeEventListener('refreshUsers', this.refreshListener);
  }

  loadUsers(): void {
    this.loading = true;
    this.error = null;

    this.userService.getUsers().subscribe({
      next: (data) => {
        this.users = data;
        this.loading = false;
      },
      error: (err) => {
        console.error('Error fetching users:', err);
        this.error = 'Failed to load users. Please try again later.';
        this.loading = false;
      }
    });
  }

  onEdit(user: User): void {
    this.editUser.emit({...user});
  }

  onDelete(id: number | undefined): void {
    if (confirm('Are you sure you want to delete this user?')) {
      this.deleteLoading = id;

      this.userService.deleteUser(id).subscribe({
        next: () => {
          this.deleteLoading = undefined;
          this.loadUsers(); // Refresh the list
        },
        error: (err) => {
          console.error('Error deleting user:', err);
          this.deleteLoading = undefined;
          alert('Failed to delete user. Please try again.');
        }
      });
    }
  }
}
