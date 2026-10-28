import { forwardRef, Module } from '@nestjs/common';

import { AiJobsModule } from '../ai-jobs/ai-jobs.module';
import { ConsentController } from './consent.controller';
import { ConsentService } from './consent.service';

@Module({
  imports: [forwardRef(() => AiJobsModule)],
  controllers: [ConsentController],
  providers: [ConsentService],
  exports: [ConsentService],
})
export class ConsentModule {}
