document.addEventListener('DOMContentLoaded', () => {
    // Initialize Health Chart
    const ctx = document.getElementById('healthChart').getContext('2d');
    
    // Creating gradient for chart
    const gradient = ctx.createLinearGradient(0, 0, 0, 400);
    gradient.addColorStop(0, 'rgba(13, 148, 136, 0.4)');
    gradient.addColorStop(1, 'rgba(13, 148, 136, 0)');

    new Chart(ctx, {
        type: 'line',
        data: {
            labels: ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'],
            datasets: [{
                label: 'Kesehatan Ternak (%)',
                data: [98, 97, 99, 96, 95, 96, 98],
                borderColor: '#14b8a6',
                borderWidth: 3,
                fill: true,
                backgroundColor: gradient,
                tension: 0.4,
                pointBackgroundColor: '#14b8a6',
                pointRadius: 4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                }
            },
            scales: {
                y: {
                    beginAtZero: false,
                    grid: {
                        color: 'rgba(255, 255, 255, 0.05)'
                    },
                    ticks: {
                        color: '#94a3b8'
                    }
                },
                x: {
                    grid: {
                        display: false
                    },
                    ticks: {
                        color: '#94a3b8'
                    }
                }
            }
        }
    });

    // Refresh button animation logic
    const refreshBtn = document.querySelector('.btn-refresh');
    refreshBtn.addEventListener('click', () => {
        const icon = refreshBtn.querySelector('i');
        icon.style.transition = 'transform 0.5s ease';
        icon.style.transform = 'rotate(360deg)';
        
        setTimeout(() => {
            icon.style.transform = 'rotate(0deg)';
            alert('Data sedang diupdate dari server Proxmox...');
        }, 500);
    });

    // Sidebar navigation simulation
    const navLinks = document.querySelectorAll('.nav-links li');
    navLinks.forEach(link => {
        link.addEventListener('click', () => {
            navLinks.forEach(l => l.classList.remove('active'));
            link.classList.add('active');
        });
    });
});
