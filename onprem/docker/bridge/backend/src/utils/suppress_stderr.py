import os

class SuppressStderr:
    def __init__(self):
        self.null_fd = None
        self.save_fd = None

    def __enter__(self):
        self.null_fd = os.open(os.devnull, os.O_WRONLY)
        self.save_fd = os.dup(2)
        os.dup2(self.null_fd, 2)
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.dispose()

    def dispose(self):
        if self.save_fd is not None:
            os.dup2(self.save_fd, 2)
            os.close(self.null_fd)
            os.close(self.save_fd)
            self.save_fd = None
            self.null_fd = None