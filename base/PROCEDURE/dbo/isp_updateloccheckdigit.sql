SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/  
/* Store Procedure:  isp_UpdateLocCheckDigit                            */  
/* Creation Date: 09-04-2013                                            */  
/* Copyright: IDS                                                       */  
/* Written by: ChewKP                                                   */  
/*                                                                      */  
/* Purpose: Update LocCheckDigit from Alphabet to Numeric               */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author    Purposes                                      */  
/************************************************************************/  
CREATE PROC [dbo].[isp_UpdateLocCheckDigit]
AS  
BEGIN  
   DECLARE @c_Loc NVARCHAR(10)
         , @nTranCount            INT
         , @nCount                INT
  
   SET @nTranCount = @@TRANCOUNT
   SET @nCount = 0 
   
   BEGIN TRAN
   SAVE TRAN UpdateLocCheckDigit
   
   -- Get From TaskManagerReason Tables
   DECLARE CursorBreak CURSOR LOCAL FAST_FORWARD READ_ONLY FOR            
   
   SELECT  Loc 
   FROM dbo.Loc WITH (NOLOCK)
   WHERE Facility LIKE '519%'
   Order by Loc
   
   OPEN CursorBreak            
   
   FETCH NEXT FROM CursorBreak INTO @c_Loc
   
   WHILE @@FETCH_STATUS <> -1     
   BEGIN
      
      UPDATE LOC WITH (ROWLOCK)
      SET LocCheckDigit  = dbo.fnc_GetLocCheckDigit2Digit(@c_Loc),
          TrafficCop = NULL 
      WHERE Loc = @c_Loc
      
      IF @@ERROR <> 0 
      BEGIN
         PRINT @@ERROR
         PRINT 'ERROR OCCURS'
         GOTO RollBackTran
      END
      
      SET @nCount = @nCount + 1
      
      FETCH NEXT FROM CursorBreak INTO @c_Loc
      
   END
   CLOSE CursorBreak            
   DEALLOCATE CursorBreak   
   
   GOTO QUIT
   
   RollBackTran:
   ROLLBACK TRAN UpdateLocCheckDigit
   CLOSE CursorBreak            
   DEALLOCATE CursorBreak   
    
   Quit:
   WHILE @@TRANCOUNT>@nTranCount -- Commit until the level we started
          COMMIT TRAN UpdateLocCheckDigit

   
   PRINT 'Total Records: '  + CAST(@nCount AS NVARCHAR(10))
END

GO