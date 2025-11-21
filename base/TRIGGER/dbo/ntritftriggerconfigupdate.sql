SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Trigger: ntrITFTriggerConfigUpdate                                   */  
/* Creation Date: 24-May-2018                                           */  
/* Copyright: IDS                                                       */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose: Trigger related Update in ITFTriggerConfig table.           */  
/*                                                                      */  
/* Input Parameters:                                                    */  
/*                                                                      */  
/* Output Parameters:                                                   */  
/*                                                                      */  
/* Usage:                                                               */  
/*                                                                      */  
/* Called By:  Interface                                                */  
/*                                                                      */  
/* PVCS Version: 1.1                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/* Date         Author    Ver.  Purposes                                */  
/************************************************************************/  
  
CREATE TRIGGER [dbo].[ntrITFTriggerConfigUpdate]  
ON  [dbo].[ITFTriggerConfig]  
FOR UPDATE  
AS  
BEGIN   
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END  
  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_debug int  
   SELECT @b_debug = 0  
   DECLARE     
     @b_Success            int         
   , @n_Err                int         
   , @n_Err2               int         
   , @c_ErrMsg             char(250)   
   , @n_Continue           int  
   , @n_StartTCnt          int  
   , @c_preprocess         char(250)   
   , @c_pstprocess         char(250)   
   , @n_Cnt                int        
  
   SELECT @n_Continue=1, @n_StartTCnt=@@TRANCOUNT  
  
   IF @n_Continue = 1 OR @n_Continue = 2   
   BEGIN    
      UPDATE ITFTriggerConfig   
      SET    EditWho  = SUSER_SNAME()
           , EditDate = GETDATE()
      FROM   ITFTriggerConfig, INSERTED  
      WHERE  ITFTriggerConfig.SeqNo = INSERTED.SeqNo
     
      SELECT @n_Err = @@ERROR, @n_Cnt = @@ROWCOUNT
     
      IF @@ERROR <> 0
      BEGIN  
         SELECT @n_Continue = 3  
         SELECT @c_ErrMsg = CONVERT(CHAR(250),@n_Err), @n_Err=68002     
         SELECT @c_ErrMsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_Err,0))   
                           + ': Update Failed On Table ITFTriggerConfig. (ntrITFTriggerConfigUpdate) ( '   
                           + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_ErrMsg)) + ' ) '  
      END
   END
END

GO