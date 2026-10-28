import { Module } from '@nestjs/common';

import { AuthModule } from '../auth/auth.module';
import { ConsentModule } from '../consent/consent.module';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

@Module({ imports: [AuthModule, ConsentModule], controllers: [UsersController], providers: [UsersService] })
export class UsersModule {}
