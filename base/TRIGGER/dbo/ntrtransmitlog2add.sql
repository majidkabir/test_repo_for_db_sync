SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Trigger: ntrTransmitlog2Add                                          */
/* Creation Date:                                                       */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:                                                             */
/* Version: 5.5                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author        Purposes                                  */
/* 04-Jul-2017  KHChan        Cater SKU table trigger (KH01)            */
/* 23-Mar-2021  KHChan        Remark Exec (KH02)                        */
/************************************************************************/

CREATE TRIGGER [dbo].[ntrTransmitlog2Add]
ON  [dbo].[TRANSMITLOG2]
FOR INSERT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @b_Success               INT            -- Populated by calls to stored procedures - was the proc successful?
         , @n_Err                   INT            -- Error number returned by stored procedure or this trigger
         , @c_ErrMsg                NVARCHAR(250)  -- Error message returned by stored procedure or this trigger
         , @n_Continue              INT
         , @n_StarttCnt             INT            -- Holds the current transaction count
			, @b_debug						INT

--(KH02) - S
   --DECLARE @c_TransmitlogKey        NVARCHAR(10)         
   --      , @c_TableName             NVARCHAR(30)         
   --      , @c_Key1                  NVARCHAR(10)         
   --      , @c_Key2                  NVARCHAR(5)          
   --      , @c_Key3                  NVARCHAR(20)         
   --      , @c_TransmitBatch         NVARCHAR(30)                  
   --      , @c_QCommd_SPName         NVARCHAR(1024)       
   --      , @c_Exist                 CHAR(1)              
   --      , @c_ExecStatements        NVARCHAR(4000)       
   --      , @c_ExecArguments         NVARCHAR(4000)
   --      , @c_TempKey1              NVARCHAR(20) --(KH01)
   --      , @c_TempKey3              NVARCHAR(20) --(KH01)
--(KH02) - E

   SELECT @n_Continue=1, @n_StarttCnt=@@TRANCOUNT
	SELECT @b_debug = 0

   IF EXISTS( SELECT 1 FROM INSERTED WHERE ArchiveCop = '9')
   BEGIN
      SELECT @n_Continue = 4
   END

   /* #INCLUDE <TRLU1.SQL> */     
--(KH02) - S
   --IF @n_Continue = 1 or @n_Continue = 2
   --BEGIN

   --   DECLARE Cur_Transmitlog_Rec CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   --   SELECT TransmitlogKey
   --        , TableName
   --        , Key1
   --        , Key2
   --        , Key3
   --        , TransmitBatch
   --   FROM   INSERTED 
   --   ORDER BY TransmitlogKey

   --   OPEN Cur_Transmitlog_Rec
   --   FETCH NEXT FROM Cur_Transmitlog_Rec INTO @c_TransmitlogKey, @c_TableName, @c_Key1, @c_Key2, @c_Key3, @c_TransmitBatch

   --   WHILE @@FETCH_STATUS <> -1
   --   BEGIN
   --      --(KH01) - Start
   --      IF @c_TableName <> 'WSSKUADDLOG'
   --      BEGIN
   --         SET @c_TempKey1 = @c_Key1
   --         SET @c_TempKey3 = @c_Key3
   --      END
   --      ELSE
   --      BEGIN
   --         SET @c_TempKey1 = @c_Key3
   --         SET @c_TempKey3 = @c_Key1
   --      END
   --      --(KH01) - End


   --      SET @c_Exist = '0'

   --      SELECT @c_QCommd_SPName    = QCommanderSP    
   --           , @c_Exist            = '1'      
   --      FROM   ITFTriggerConfig WITH (NOLOCK)
   --      WHERE  TargetTable         = 'TRANSMITLOG2' 
   --      AND    Tablename           = @c_TableName 
   --      --AND    StorerKey           = @c_Key3 --(KH01)
   --      AND    StorerKey           = @c_TempKey3 --(KH01)
			--AND   (QCommanderSP IS NOT NULL AND QCommanderSP <> '')

		 --  IF @c_Exist = '1' AND ISNULL(@c_QCommd_SPName, '') <> ''
		 --  BEGIN

   --         SET @c_ExecStatements = ''
   --         SET @c_ExecArguments = ''

   --         SET @c_ExecStatements = N'EXEC @c_QCommd_SPName '
   --                               + ' @c_Table				= ''TRANSMITLOG2'''
   --                               + ',@c_TransmitLogKey	= @c_TransmitLogKey'
   --                               + ',@c_TableName			= @c_TableName'
   --                               --+ ',@c_Key1				= @c_Key1' --(KH01)
   --                               + ',@c_Key1				= @c_TempKey1' --(KH01)
   --                               + ',@c_Key2				= @c_Key2'
   --                               --+ ',@c_Key3				= @c_Key3' --(KH01)
   --                               + ',@c_Key3				= @c_TempKey3' --(KH01)
   --                               + ',@c_TransmitBatch	= @c_TransmitBatch'  
			--								 + ',@b_Debug				= @b_debug'
   --                               + ',@b_Success			= @b_Success   OUTPUT'
   --                               + ',@n_Err					= @n_Err       OUTPUT'
   --                               + ',@c_ErrMsg				= @c_ErrMsg    OUTPUT'                            

   --         SET @c_ExecArguments = N'@c_QCommd_SPName    NVARCHAR(125)'
   --                              + ',@c_TransmitLogKey   NVARCHAR(10)'
   --                              + ',@c_TableName        NVARCHAR(30)'
   --                              --+ ',@c_Key1             NVARCHAR(10)'--(KH01)
   --                              + ',@c_TempKey1             NVARCHAR(20)'--(KH01)
   --                              + ',@c_Key2             NVARCHAR(5)'
   --                              --+ ',@c_Key3             NVARCHAR(20)'--(KH01)
   --                              + ',@c_TempKey3             NVARCHAR(20)'--(KH01)
   --                              + ',@c_TransmitBatch    NVARCHAR(30)' 
			--								+ ',@b_debug				INT'   
   --                              + ',@b_Success          INT             OUTPUT'                      
   --                              + ',@n_Err              INT             OUTPUT' 
   --                              + ',@c_ErrMsg           NVARCHAR(250)   OUTPUT' 
                        
   --         EXEC sp_ExecuteSql @c_ExecStatements 
   --                          , @c_ExecArguments 
   --                          , @c_QCommd_SPName
   --                          , @c_TransmitLogKey
   --                          , @c_TableName
   --                          --, @c_Key1 --(KH01)
   --                          , @c_TempKey1 --(KH01)
   --                          , @c_Key2
   --                          --, @c_Key3 --(KH01)
   --                          , @c_TempKey3 --(KH01)
   --                          , @c_TransmitBatch   
			--						  , @b_debug                           
   --                          , @b_Success         OUTPUT                       
   --                          , @n_Err             OUTPUT  
   --                          , @c_ErrMsg          OUTPUT
             
   --         IF @@ERROR <> 0 
   --         BEGIN
   --            SELECT @n_continue = 3
   --            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=63811
   --            SELECT @c_errmsg= "NSQL" + CONVERT(char(5),@n_err) + ": Error Executing SP " + @c_QCommd_SPName + " Fail. (ispGenTRANSMITLOG2) ( SQLSvr MESSAGE=" + @c_errmsg + " ) "             	
   --         END
   --      END
         
   --      FETCH NEXT FROM Cur_Transmitlog_Rec INTO @c_TransmitlogKey, @c_TableName, @c_Key1, @c_Key2, @c_Key3, @c_TransmitBatch
   --   END -- WHILE @@FETCH_STATUS <> -1
   --   CLOSE Cur_Transmitlog_Rec
   --   DEALLOCATE Cur_Transmitlog_Rec
   --END
--(KH02) - E

   /* #INCLUDE <TRLU2.SQL> */

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      IF @@TRANCOUNT = 1 and @@TRANCOUNT >= @n_StarttCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StarttCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_Err, @c_ErrMsg, 'ntrTransmitlog2Add'
      RAISERROR (@c_ErrMsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StarttCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO