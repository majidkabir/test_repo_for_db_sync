SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
  
 /************************************************************************/    
/* Stored Procedure: rdtHouseKeeping                                    */    
/* Copyright: IDS                                                       */    
/*                                                                      */    
/* Purpose: Delete unnecessary records                                  */    
/*                                                                      */    
/* Updates:                                                             */    
/* Date         Author  Ver   Purposes                                  */    
/* 2004-03-07   Shong         Created                                   */    
/* 2006-12-13   Dhung         Add in RDTTrace and RDTTraceSummary table */    
/*                            Various RDTMobRec section changes         */    
/* 2007-04-05   James         SOS#72719 - Purge RDT.RDTMessage records  */    
/*                            that more than 3 days                     */    
/* 2009-03-20   TLTING        SOS#132168 Alter table rdtTtraceSummary   */  
/*                            remove column  MS2000_UP                  */   
/*                            Add column MS2000_5000, MS5000_UP         */  
/* 2010-07-09   TLTING   1.4  Purge RDTPrintJob& rdtTraceSummary        */    
/* 2010-07-09   TLTING   1.4  Purge RDTPrintJob& condition  > 30 day    */            
/* 2014-03-21   KHLim    1.5  SOS#303589 Purge RDT.RDTMessage (KH01)    */            
/* 2014-03-21   KHLim    1.6  SOS#313823 add default SP parameter (KH02)*/ 
/* 2015-08-26   Shong01  1.7  Remove rdtMobRec with Func=0 and RETIRED  */           
/************************************************************************/    
    
CREATE PROC [RDT].[rdtHouseKeeping] (  
    @nDayOfTrace   INT = 7  
   ,@nDayOfMsg     INT = 15  
)  
AS    
BEGIN    
   SET NOCOUNT ON     
   SET QUOTED_IDENTIFIER OFF     
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF  
    
   /*-------------------------------------------------------------------------------    
   RDTMobRec    
      Auto delete by trigger:    
      RDTXML    
      RDTXML_Elm    
      RDTXML_Root    
      RDTSession_Data    
    
   RDTMobRec default to keep 1 day data    
   -------------------------------------------------------------------------------*/    
   DECLARE @nMobile INT    
   DECLARE @tMobRec TABLE    
   (    
      Mobile INT NOT NULL    
   )    
    
   -- Get records to be deleted    
   INSERT INTO @tMobRec    
   SELECT Mobile    
   FROM RDT.RDTMOBREC (NOLOCK)    
   WHERE (DATEDIFF( Hour, EditDate, GETDATE()) >= 24)  
   OR   (UserName = 'RETIRED') -- SHONG01
   OR   (Func=0 AND DATEDIFF( Hour, EditDate, GETDATE()) >= 1) -- SHONG01
       
   -- Prepare cursor    
   DECLARE @curMobRec CURSOR    
   SET @curMobRec = CURSOR FOR    
      SELECT Mobile    
      FROM @tMobRec    
   OPEN @curMobRec    
    
   -- Loop    
   FETCH NEXT FROM @curMobRec INTO @nMobile    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      -- Delete the RDTMobRec record    
      BEGIN TRAN    
      DELETE RDT.RDTMobRec WITH (ROWLOCK) WHERE Mobile = @nMobile    
      COMMIT TRAN    
    
      FETCH NEXT FROM @curMobRec INTO @nMobile    
   END    
   CLOSE @curMobRec    
   DEALLOCATE @curMobRec    
    
    
   /*-------------------------------------------------------------------------------    
   RDTTrace    
   RDTTraceSummary    
    
   RDTTrace (default to keep only @nDayOfTrace data). Past data will be summarized into    
   RDTTraceSummary table    
   -------------------------------------------------------------------------------*/    
   DECLARE @nDaysToKeep INT    
   SET @nDaysToKeep = @nDayOfTrace    
    
   -- Calculate date @nDaysToKeep ago    
   DECLARE @dDate DATETIME    
   SET @dDate = CONVERT( NVARCHAR(10), GETDATE(), 120) -- Get the date, throw away time    
   SET @dDate = @dDate - @nDaysToKeep    
    
   -- Create RDTTraceSummary record    
   INSERT INTO rdt.rdtTraceSummary (TransDate, Hour24, Usr, InFunc, InStep, OutStep, AvgTime, TotalTrans, MinTime, MaxTime, MS0_1000, MS1000_2000, MS2000_5000, MS5000_UP)    
   SELECT     
      CONVERT( NVARCHAR(10), StartTime, 120),    
      DATEPART( hour, StartTime),          Usr,    
      InFunc,    
      InStep,    
      OutStep,     
      SUM( TimeTaken) / COUNT( 1) AvgTime,    
      COUNT( 1) TotalTrans,    
      MIN( TimeTaken) MinTime,    
      MAX( TimeTaken) MaxTime,    
      IsNULL( SUM( CASE WHEN TimeTaken <= 1000 THEN 1 ELSE 0 END), 0) MS0_1000,    
      IsNULL( SUM( CASE WHEN TimeTaken > 1000 AND TimeTaken <= 2000 THEN 1 ELSE 0 END), 0) MS1000_2000,    
      IsNULL( SUM( CASE WHEN TimeTaken > 2000 AND TimeTaken < 5000 THEN 1 ELSE 0 END), 0) MS2000_5000,    
      IsNULL( SUM( CASE WHEN TimeTaken >= 5000 THEN 1 ELSE 0 END), 0) MS5000_UP    
   FROM RDT.RDTTrace (NOLOCK)    
   WHERE StartTime < @dDate    
   GROUP BY CONVERT( NVARCHAR(10), StartTime, 120), DATEPART( hour, StartTime), Usr, InFunc, InStep, OutStep    
    
   -- If not error, purge the RDTTrace record    
   IF @@ERROR = 0    
   BEGIN    
      DECLARE @nRowRef INT    
      DECLARE @tTrace TABLE    
      (    
         RowRef INT NOT NULL    
      )    
    
      -- Get records to be deleted    
      INSERT INTO @tTrace        SELECT RowRef     
      FROM RDT.RDTTrace (NOLOCK)    
      WHERE StartTime < @dDate    
    
      -- Prepare cursor    
      DECLARE @curTrace CURSOR    
      SET @curTrace = CURSOR FOR    
         SELECT RowRef    
         FROM @tTrace    
      OPEN @curTrace    
    
      -- Loop    
      FETCH NEXT FROM @curTrace INTO @nRowRef    
      WHILE @@FETCH_STATUS = 0    
      BEGIN    
         -- Delete the RDTTrace record    
         BEGIN TRAN    
         DELETE RDT.RDTTrace WITH (ROWLOCK) WHERE RowRef = @nRowRef    
         COMMIT TRAN    
    
         FETCH NEXT FROM @curTrace INTO @nRowRef    
      END    
      CLOSE @curTrace    
      DEALLOCATE @curTrace    
  
   /*-------------------------------------------------------------------------------    
   rdtTraceSummary  
   Purge RDT.rdtTraceSummary records that more than 60 days - Start    
   -------------------------------------------------------------------------------*/    
      
   -- Prepare cursor      
 DECLARE cur_item CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT RowRef      
   FROM RDT.rdtTraceSummary (NOLOCK)      
   WHERE DATEDIFF( Day, TransDate, GETDATE()) > 366    
    
   OPEN cur_item      
      
   -- Loop      
   FETCH NEXT FROM cur_item INTO @nRowRef      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      -- Delete the RDTMobRec record      
      BEGIN TRAN      
      DELETE RDT.rdtTraceSummary WITH (ROWLOCK) WHERE RowRef = @nRowRef      
      COMMIT TRAN      
      
      FETCH NEXT FROM cur_item INTO @nRowRef      
   END      
   CLOSE cur_item      
   DEALLOCATE cur_item      
   /*-------------------------------------------------------------------------------    
   rdtTraceSummary  
   Purge RDT.rdtTraceSummary records that more than 366 days - End    
   -------------------------------------------------------------------------------*/    
       
   /*-------------------------------------------------------------------------------    
   RDTMessage    
   Purge RDT.RDTMessage records that more than @nDayOfMsg - Start    --KH01 KH02  
   -------------------------------------------------------------------------------*/    
   DECLARE @nSeqNo INT    
   DECLARE @tMsgRec TABLE    
   (    
      SeqNo INT NOT NULL    
   )    
    
   -- Get records to be deleted    
   INSERT INTO @tMsgRec    
   SELECT SeqNo    
   FROM RDT.RDTMessage (NOLOCK)    
   WHERE DATEDIFF( Day, AddDate, GETDATE()) > @nDayOfMsg   --KH01 KH02  
       
   -- Prepare cursor    
   DECLARE @curMsgRec CURSOR    
   SET @curMsgRec = CURSOR FOR    
      SELECT SeqNo    
      FROM @tMsgRec    
   OPEN @curMsgRec    
    
   -- Loop    
   FETCH NEXT FROM @curMsgRec INTO @nSeqNo    
   WHILE @@FETCH_STATUS = 0    
   BEGIN    
      -- Delete the RDTMobRec record    
      BEGIN TRAN    
      DELETE RDT.RDTMessage WITH (ROWLOCK) WHERE SeqNo = @nSeqNo    
      COMMIT TRAN    
    
      FETCH NEXT FROM @curMsgRec INTO @nSeqNo    
   END    
   CLOSE @curMsgRec    
   DEALLOCATE @curMsgRec    
    
   /*-------------------------------------------------------------------------------    
   RDTMessage    
   Purge RDT.RDTMessage records that more than @nDayOfMsg  - End  --KH01 KH02  
   -------------------------------------------------------------------------------*/    
    
   END    
  
   /*-------------------------------------------------------------------------------    
   RDTPrintJob  
   Purge RDT.RDTPrintJob records that more than 60 days - Start    
   -------------------------------------------------------------------------------*/    
  
   DECLARE @nJobId INT      
      
   -- Prepare cursor      
 DECLARE cur_item CURSOR LOCAL FAST_FORWARD READ_ONLY FOR     
   SELECT JobId      
   FROM RDT.RDTPRINTJOB  with (NOLOCK)    
   WHERE ((DATEDIFF(DAY, AddDate, GETDATE()) > 6    
   AND JobStatus = '9')    
   OR ((DATEDIFF(DAY, AddDate , GETDATE()) > 30) ) )    
    
   OPEN cur_item      
      
   -- Loop      
   FETCH NEXT FROM cur_item INTO @nJobId      
   WHILE @@FETCH_STATUS = 0      
   BEGIN      
      -- Delete the RDTMobRec record      
      BEGIN TRAN      
      DELETE RDT.RDTPrintJob WITH (ROWLOCK) WHERE JobId = @nJobId      
      COMMIT TRAN      
      
      FETCH NEXT FROM cur_item INTO @nJobId      
   END      
   CLOSE cur_item      
   DEALLOCATE cur_item      
   /*-------------------------------------------------------------------------------    
   RDTPrintJob  
   Purge RDT.RDTPrintJob records that more than 60 days - End    
   -------------------------------------------------------------------------------*/    
END    

GO