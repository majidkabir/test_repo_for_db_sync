SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPRREC01                                            */
/* Creation Date: 15-APR-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#308181 - CN_HM(ECOM)_update toid to userdefine01           */                               
/*        : Before finalize ASN                                            */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.0                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 08/06/2018   NJOW01  1.0   WMS-5074 Trim left 2 digits userdefine01     */
/* 20/12/2019   CSCHONG 1.1   WMS-11374 revised logic (CS01)               */
/***************************************************************************/  
CREATE PROC [dbo].[ispPRREC01]  
(     @c_Receiptkey  NVARCHAR(10)  
  ,   @c_ReceiptLineNumber  NVARCHAR(5) = ''      
  ,   @b_Success     INT           OUTPUT
  ,   @n_Err         INT           OUTPUT
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Cnt                INT
         , @n_Continue           INT 
         , @n_StartTranCount     INT 
   --CS01 START
   DECLARE   @c_ExecArguments    NVARCHAR(4000)           
            ,@c_sql              NVARCHAR(MAX)          
            ,@c_Updatesql        NVARCHAR(MAX)  
            ,@c_Upd1sql          NVARCHAR(MAX)  
            ,@c_Upd2sql          NVARCHAR(MAX) 
            ,@c_wheresql         NVARCHAR(MAX)   
            ,@c_conditionsql     NVARCHAR(MAX)     
            ,@c_storerconfig     NVARCHAR(150)
            ,@c_Opt1             NVARCHAR(150) 
            ,@c_storerkey        NVARCHAR(20)
        

   DECLARE @c_ExecStatements NVARCHAR(MAX)
   DECLARE @c_ExecStatements2 NVARCHAR(MAX)
  -- DECLARE @c_ExecWhere NVARCHAR(4000),@c_ExecHaving NVARCHAR(4000),@c_ExecOrderBy NVARCHAR(4000)    
  --CS01 END
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTranCount = @@TRANCOUNT  
   SET @c_storerkey = ''                 --CS01
   SET @c_Opt1 = ''                      --CS01
   SET @c_sql = ''                       --CS01

   IF NOT EXISTS( SELECT 1
                  FROM RECEIPT WITH (NOLOCK)
                  WHERE ReceiptKey = @c_Receiptkey
                  AND DocType = 'A'
                )
   BEGIN
      GOTO QUIT_SP        
   END

   --CS01 START

   SELECT @c_storerkey = Storerkey
   FROM RECEIPT (nolock)
   where Receiptkey = @c_Receiptkey


   SELECT @c_Opt1 = ISNULL(Option1,'')
   FROM STORERCONFIG (NOLOCK)
   WHERE Storerkey = @c_storerkey
   AND Configkey = 'PreFinalizeReceiptSP'

   IF ISNULL(@c_Opt1,'') = ''
   BEGIN
     SET @c_Opt1 = 'HM%'
   END
   ELSE
   BEGIN
    SET @c_Opt1 = @c_Opt1 + '%'
   END


   --CS01 END

   SET @c_Updatesql = N' UPDATE RECEIPTDETAIL WITH (ROWLOCK)'

   SET @c_Upd1sql = N' SET  UserDefine01 =  CASE WHEN Toid like @c_Opt1 THEN Toid ELSE UserDefine01 END' 

   SET @c_Upd2sql = N',TOID = CASE WHEN ToID = ''SSCC'' THEN LTRIM(RIGHT(RTRIM(UserDefine01),18)) ELSE ToID END ' + CHAR(13) +
                     ',EditDate = GETDATE() ' + CHAR(13) +
                     ',EditWho  = SUSER_NAME()' + CHAR(13) +
                     ',Trafficcop = NULL ' + CHAR(13) 

   SET @c_wheresql = N'WHERE ReceiptKey = @c_Receiptkey '
   SET @c_conditionsql = N' AND (Toid like @c_Opt1 OR ToID = ''SSCC'') '

   SET @c_sql = @c_Updatesql + CHAR(13) + @c_Upd1sql + CHAR(13) + @c_Upd2sql + CHAR(13) + @c_wheresql +  CHAR(13) + @c_conditionsql


   SET @c_ExecArguments = N'   @c_Opt1         NVARCHAR(120)'    
                         +   ',@c_Receiptkey   NVARCHAR(20)' 

  IF  @b_Debug = '1'
  BEGIN
    SELECT @c_Receiptkey  '@c_Receiptkey ', @c_Opt1 '@c_Opt1'
    SELECT @c_sql
  --GOTO QUIT_SP
  
  END                    
                         
   EXEC sp_ExecuteSql     @c_SQL     
                        , @c_ExecArguments    
                        , @c_Opt1    
                        , @c_Receiptkey

 --CS01 Remove
 /*  UPDATE RECEIPTDETAIL WITH (ROWLOCK)
   --SET  UserDefine01 = ToID
   SET  UserDefine01 = CASE WHEN ToID Like 'HM%' THEN ToID ELSE UserDefine01 END
      , ToID         = CASE WHEN ToID = 'SSCC' THEN LTRIM(RIGHT(RTRIM(UserDefine01),18)) ELSE ToID END --NJOW01
      , EditDate = GETDATE()
      , EditWho  = SUSER_NAME()
      , Trafficcop = NULL
   WHERE ReceiptKey = @c_Receiptkey
   AND   (ToID Like 'HM%' OR ToID = 'SSCC')
   */

   SET @n_err = @@ERROR  
   IF @n_err <> 0   
   BEGIN  
      SET @n_continue = 3  
      SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)  
      SET @n_err = 81010    
      SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update RECEIPTDETAIL Table Failed. (ispPRREC01)' 
                   + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
      GOTO QUIT_SP
   END  

   QUIT_SP:
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      RETURN
   END 
END

GO