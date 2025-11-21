SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp_PrintEnd                                       */
/* Creation Date: 04-Feb-2013                                           */
/* Copyright: IDS                                                       */
/* Written by:                                                          */
/*                                                                      */
/* Purpose:  SOS#268254-Nike_DeliveryNote (MY/SG/TW)                    */
/*                                                                      */
/* Usage:  Call from u_dw.PrintEnd Event                                */
/*                                                                      */
/* Called By: Exceed                                                    */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver.  Purposes                                  */
/* 04-11-2015   CSCHONG 1.1   TH LIT report (CS01)                      */
/* 27-Feb-2017  CSCHONG 1.2   WMS-1174 new loadsheet report (CS02)      */
/* 17-OCT-2017  CSCHONG 1.3   WMS-2952 - Update print qty (CS03)        */
/************************************************************************/

CREATE PROC [dbo].[isp_PrintEnd] 
      (@c_datawindow NVARCHAR(50)
      ,@c_Arguement1 NVARCHAR(30)
      ,@c_Arguement2 NVARCHAR(30) = ''
      ,@c_Arguement3 NVARCHAR(30) = ''
      ,@c_Arguement4 NVARCHAR(30) = ''
      ,@c_Arguement5 NVARCHAR(30) = ''
      )
AS
BEGIN
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTranCount  INT
         , @n_Continue        INT
         , @b_Success         INT
         , @n_Err             INT
         , @c_ErrMsg          NVARCHAR(255) 

  
  DECLARE @c_PickHeaderkey      NVARCHAR(18)   --(CS01)
         ,@n_Currentcopy        INT            --(CS02)
         ,@n_PrintCopy          INT            --(CS02)
         ,@n_TTLPrintCopy       INT            --(CS02)
   
         
   SET @n_StartTranCount= @@TRANCOUNT
   SET @n_Continue      = 1
   SET @b_Success       = 1
   SET @n_Err           = 0
   SET @c_ErrMsg        = ''
   SET @c_PickHeaderkey = ''      --(CS01)
   SET @n_Currentcopy   = 1       --(CS02)
   SET @n_PrintCopy     = 1       --(CS02)
   SET @n_TTLPrintCopy  = 0       --(CS02)
   
   IF @c_datawindow = 'r_dw_delivery_order_06'
   BEGIN
      UPDATE MBOL WITH (ROWLOCK)
      SET Userdefine10 = CASE WHEN ISNUMERIC(Userdefine10)= 1 THEN CONVERT(NVARCHAR, CONVERT(INT, Userdefine10) + 1)
                              ELSE 2
                              END 
         ,Trafficcop = NULL
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
      WHERE MBOLKey  = @c_Arguement1

      IF @@Error <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 26001
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update MBOL table Fail. (isp_PrintEnd)'
      END
   END
   /*CS01 Start*/
   ELSE IF @c_datawindow = 'r_th_pickslip03'
   BEGIN

      UPDATE PICKHEADER WITH (ROWLOCK)
      SET Picktype = '1'
         ,Trafficcop = NULL
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
      WHERE Orderkey  = @c_Arguement1

      IF @@Error <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 26001
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update Pickheader table Fail. (isp_PrintEnd)'
      END
   END
   /*CS01 End*/
   /*CS02 Start*/
   ELSE IF @c_datawindow = 'r_dw_loadsheet09'
   BEGIN

      UPDATE LOADPLAN WITH (ROWLOCK)
      SET userdefine01 = 'Y'
         ,Trafficcop = NULL
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
      WHERE loadkey  = @c_Arguement1

      IF @@Error <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 26001
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update loadplan table Fail. (isp_PrintEnd)'
      END
   END
   /*CS02 End*/
   /*CS03 Start*/
   ELSE IF @c_datawindow = 'r_dw_antidiversion_rpt_tw'
   BEGIN
   	
   	SET @n_PrintCopy = CONVERT (INT,@c_Arguement3)

	   SELECT @n_Currentcopy = CAST(UDF03 AS INT)
	   FROM CODELKUP WITH (NOLOCK)
	   WHERE Listname = 'serialno'
      AND code = @c_Arguement1 + @c_Arguement2
      AND storerkey=@c_Arguement4 
      
      SET @n_TTLPrintCopy = @n_Currentcopy + @n_PrintCopy

      UPDATE CODELKUP WITH (ROWLOCK)
      SET UDF03 = right('000000'+convert(varchar(7), @n_TTLPrintCopy), 7)
         ,EditWho    = SUSER_NAME()
         ,EditDate   = GETDATE()
      WHERE Listname = 'serialno'
      AND code = @c_Arguement1 + @c_Arguement2
      AND storerkey=@c_Arguement4 

      IF @@Error <> 0 
      BEGIN
         SET @n_Continue = 3
         SET @n_Err = 26001
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err) + ': Update codelkup table Fail. (isp_PrintEnd)'
      END
   END
   /*CS03 End*/
   IF @n_Continue = 3
   BEGIN
      SET @b_Success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCount
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCount
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PrintEnd'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTranCount
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO