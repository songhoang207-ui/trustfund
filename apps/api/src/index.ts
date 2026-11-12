import dotenv from 'dotenv';
import cors from 'cors';
import express from 'express';

dotenv.config({ path: '../../.env' });

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_req, res) => res.json({ status: 'ok' }));

// TODO: Add campaign, donation, milestone and transaction read endpoints.
// TODO: Add the Fuji event indexer after the contract ABI and address are available.

const port = Number(process.env.PORT ?? 4000);
app.listen(port, () => console.info(`TrustFund API listening on ${port}`));
