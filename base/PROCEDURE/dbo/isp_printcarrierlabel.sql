SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_PrintCarrierLabel                                       */
/* Creation Date: 11-Mar-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Print Custom Carrier Label                                  */
/*        : SOS#335066 - [TW-L'Oreal] Print Carrier Label from          */
/*          Customerized Report                                         */
/* Called By:                                                           */
/*          : Print Carrier Label.Print.click                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_PrintCarrierLabel] 
            @c_PickSlipNo     NVARCHAR(10)  
         ,  @n_NoOfCarton     INT
         ,  @c_ContainerType  NVARCHAR(10)
--         ,  @c_LabelType      NVARCHAR(30)  
--         ,  @c_UserID         NVARCHAR(18)     
--         ,  @c_PrinterID      NVARCHAR(50)        
--         ,  @c_NoOfCopy       NVARCHAR(5) 
         ,  @b_UpdateOrders   INT = 0   
         ,  @b_Success        INT = 1  OUTPUT 
         ,  @n_err            INT = 0  OUTPUT 
         ,  @c_errmsg         NVARCHAR(255) = '' OUTPUT
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_StartTCnt       INT
         , @n_Continue        INT 
         , @n_RecCnt          INT
         
         , @c_SQL             NVARCHAR(MAX)
         , @c_SQLParm         NVARCHAR(MAX)

         , @c_Orderkey        NVARCHAR(10)
         , @c_Storerkey       NVARCHAR(15)

         , @dt_ScanInDate     DATETIME
         , @dt_ScanOutDate    DATETIME
         
   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @b_Success  = 1
   SET @n_err      = 0

   SET @n_RecCnt   = 0
   SELECT @c_Orderkey = Orderkey 
         ,@n_RecCnt   = 1
   FROM PICKHEADER WITH (NOLOCK)
   WHERE PickheaderKey = @c_PickSlipNo

   IF @n_RecCnt = 0 
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 61005  
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Pickslip # (isp_PrintCarrierLabel)'
      GOTO QUIT_SP 
   END


   IF @n_NoOfCarton < 0 
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 61010
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Cartons # (isp_PrintCarrierLabel)'
      GOTO QUIT_SP 
   END

   SELECT @c_Storerkey = Storerkey
   FROM ORDERS WITH (NOLOCK)
   WHERE Orderkey = @c_Orderkey

   
   BEGIN TRAN
   IF @b_UpdateOrders = 1
   BEGIN
      UPDATE ORDERS WITH (ROWLOCK)
      SET ContainerQty = @n_NoofCarton 
        , ContainerType= @c_ContainerType
        , EditWho = SUSER_NAME()
        , EditDate= GETDATE()
        , Trafficcop = NULL   
      WHERE Orderkey = @c_Orderkey

      SET @n_err = @@ERROR 

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61020  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table ORDERS. (isp_PrintCarrierLabel)' 
         GOTO QUIT_SP
      END 
   END
   
   IF EXISTS ( SELECT 1 
               FROM STORERCONFIG WITH (NOLOCK)
               WHERE Storerkey = @c_Storerkey
               AND Configkey = 'PRNCARRIERLBLNAUTOSCANOUT'
               AND SValue = '1'
             )
   BEGIN
      SELECT @dt_ScanInDate = ScanInDate
            ,@dt_ScanOutDate = ScanOutDate
      FROM PICKINGINFO WITH (NOLOCK) 
      WHERE PickSlipNo = @c_PickSlipNo
            
      IF @dt_ScanInDate IS NULL OR @dt_ScanInDate = '1900-01-01'
      BEGIN
            -- INSERT AND SCANOUT
         INSERT INTO PICKINGINFO (PickSlipNo, ScanIndate,PickerID, Trafficcop)  
         VALUES (@c_PickSlipNo, GETDATE(), SUSER_NAME(), 'U')  

         SET @n_err = @@ERROR 

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert Failed into Table PICKINGINFO. (isp_PrintCarrierLabel)' 
            GOTO QUIT_SP
         END 
      END 

      IF @dt_ScanOutDate IS NULL OR @dt_ScanOutDate = '1900-01-01'
      BEGIN
         UPDATE PICKINGINFO WITH (ROWLOCK)
         SET ScanOutDate = GETDATE()
         WHERE PickSlipNo = @c_PickSlipNo 

         SET @n_err = @@ERROR 

         IF @n_err <> 0    
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 61030  -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
            SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update Failed on Table PICKINGINFO. (isp_PrintCarrierLabel)' 
            GOTO QUIT_SP
         END     
      END
   END
/*
   SET @c_SQL = N'EXECUTE isp_BT_GenBartenderCommand ' + CHAR(13) +    
      ' @cPrinterID  = @c_PrinterID '                 + CHAR(13) +  
      ',@c_LabelType = @c_LabelType '                 + CHAR(13) +     
      ',@c_userid    = @c_userid '                    + CHAR(13) +  
      ',@c_Parm01    = @c_PickSlipNo '                + CHAR(13) +  
      ',@c_Parm02    = '''' '                         + CHAR(13) +  
      ',@c_Parm03    = '''' '                         + CHAR(13) +  
      ',@c_Parm04    = '''' '                         + CHAR(13) +  
      ',@c_Parm05    = '''' '                         + CHAR(13) +  
      ',@c_Parm06    = '''' '                         + CHAR(13) +  
      ',@c_Parm07    = '''' '                         + CHAR(13) +  
      ',@c_Parm08    = '''' '                         + CHAR(13) +  
      ',@c_Parm09    = '''' '                         + CHAR(13) +  
      ',@c_Parm10    = '''' '                         + CHAR(13) +  
      ',@c_Storerkey = @c_Storerkey '                 + CHAR(13) + 
      ',@c_NoCopy    = @c_NoOfCopy '                  + CHAR(13) +        
      ',@b_Debug     = 0 '                            + CHAR(13) +  
      ',@c_Returnresult =''N'' '                      + CHAR(13) +  
      ',@n_err          = @n_err    OUTPUT '          + CHAR(13) +  
      ',@c_errmsg       = @c_errmsg OUTPUT '           

   SET @c_SQLParm =  N'  @c_PrinterID  NVARCHAR(50) '  
                  +   ', @c_LabelType  NVARCHAR(30) '
                  +   ', @c_userid     NVARCHAR(18) '
                  +   ', @c_PickSlipNo NVARCHAR(10) '
                  +   ', @c_Storerkey  NVARCHAR(15) '
                  +   ', @c_NoOfCopy   NVARCHAR(5) '
                  +   ', @n_Err        INT OUTPUT '
                  +   ', @c_ErrMsg     NVARCHAR(250) OUTPUT'

          
   EXEC sp_ExecuteSQL @c_SQL
                  , @c_SQLParm
                  , @c_PrinterID  
                  , @c_LabelType
                  , @c_userid
                  , @c_PickSlipNo
                  , @c_Storerkey
                  , @c_NoOfCopy
                  , @n_Err       OUTPUT
                  , @c_ErrMsg    OUTPUT 
 
  
   IF @n_Err <> 0    
   BEGIN  
      SET @n_Continue= 3    
      SET @n_Err     = 61035 
      SET @c_ErrMsg  =  'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Failed to EXEC isp_BT_GenBartenderCommand' +  
                        CASE WHEN ISNULL(@c_ErrMsg, '') <> '' THEN ' - ' + @c_ErrMsg ELSE '' END + ' (isp_PrintCarrierLabel)'
      GOTO QUIT_SP                          
   END 
*/

QUIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_Success = 0
      IF  @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTCnt
         BEGIN
            COMMIT TRAN
         END
      END
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_PrintCarrierLabel'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END -- procedure

GO