SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 

/************************************************************************/  
/* Trigger: ntrQcmd_TransmitlogConfigUpdate                             */  
/* Creation Date: 23-Oct-2017                                           */  
/* Copyright: IDS                                                       */  
/* Written by: MCTang                                                   */  
/*                                                                      */  
/* Purpose: Trigger related Update in Qcmd_TransmitlogConfig table.     */  
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
  
CREATE TRIGGER [dbo].[ntrQcmd_TransmitlogConfigUpdate]  
ON  [dbo].[QCmd_TransmitlogConfig]  
FOR UPDATE  
AS  
BEGIN   
   IF @@ROWCOUNT = 0  
   BEGIN  
      RETURN  
   END  
  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_debug int  
   SELECT @b_debug = 0  
   DECLARE     
     @b_Success            int         
   , @n_err                int         
   , @n_err2               int         
   , @c_errmsg             char(250)   
   , @n_continue           int  
   , @n_starttcnt          int  
   , @c_preprocess         char(250)   
   , @c_pstprocess         char(250)   
   , @n_cnt                int        
  
   SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT  
  
   IF @n_continue = 1 OR @n_continue = 2   
   BEGIN    

      UPDATE Qcmd_TransmitlogConfig   
      SET    EditWho  = SUSER_SNAME()
           , EditDate = GETDATE()
      FROM   Qcmd_TransmitlogConfig, INSERTED  
      WHERE  Qcmd_TransmitlogConfig.RowRefNo = INSERTED.RowRefNo
     
      SELECT @n_err = @@ERROR, @n_cnt = @@ROWCOUNT
     
      IF @@ERROR <> 0
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=68002     
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                           + ': Update Failed On Table Qcmd_TransmitlogConfig. (ntrQcmd_TransmitlogConfigUpdate) ( '   
                           + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '  
      END
   END
END

GO