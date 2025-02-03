const request = require('supertest');
const app = require('/Users/yeshnavya/Downloads/backend_defi_project/src/app.js'); 

describe('GET /api/energy', () => {
    it('should return 200 and a message', async () => {
        const response = await request(app).get('/api/energy');
        expect(response.status).toBe(200);
        expect(response.body.message).toBe('Energy API Working!');
    });
});
