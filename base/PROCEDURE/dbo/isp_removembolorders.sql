SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_RemoveMBOLOrders                               */
/* Creation Date: 06-JUL-2012                                           */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#249041-FNPC Configkey-Move MBOL to new/other CBOL       */
/*                                                                      */
/* Called By: w_popup_move_mboldetail - ue_remove()                     */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 15-Apr-2014  TLTING    1.0   SQL2012 Compatible                      */
/* 27-Feb-2017  TLTING    1.1   variable Nvarchar                       */
/************************************************************************/

CREATE PROC [dbo].[isp_RemoveMBOLOrders]
      @c_MBOLKey        NVARCHAR(10)
   ,  @c_MBOLlineNumber NVARCHAR(5) 
   ,  @b_success        INT         OUTPUT
   ,  @n_err            INT         OUTPUT
   ,  @c_errmsg         NVARCHAR(225)   OUTPUT    
AS
BEGIN
   SET NOCOUNT ON      
   SET ANSI_NULLS OFF      
   SET QUOTED_IDENTIFIER OFF      
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE @n_Continue        INT
         , @n_StartTCnt       INT


   DECLARE @c_Orderkey        NVARCHAR(10)
         , @c_Status          NVARCHAR(10)
         , @nQtyAllocPicked   INT

   SET @n_Continue      = 1
   SET @n_StartTCnt     = @@TRANCOUNT

   SET @c_Orderkey      = '' 
   SET @c_Status        = ''
   SET @nQtyAllocPicked = 0 

   BEGIN TRAN
   SELECT @c_Orderkey = OH.Orderkey
         ,@c_Status = ISNULL(RTRIM(OH.Status),'')
         ,@nQtyAllocPicked = ISNULL(SUM(PD.Qty),0)
   FROM MBOLDETAIL MB WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK)      ON (MB.Orderkey = OH.Orderkey)
   LEFT JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   WHERE MB.MBOLKey = @c_MBOLKey
   AND   MB.MBOLLineNumber = @c_MBOLlineNumber
   AND   OH.Status < '9'
   AND   OH.SOStatus <> '9'
   GROUP BY OH.Orderkey
         ,  ISNULL(RTRIM(OH.Status),'')

   IF @c_Status = '0' AND @nQtyAllocPicked = 0
   BEGIN
      UPDATE ORDERS WITH (ROWLOCK)
      SET SOStatus = 'CANC'
         ,EditWho  = SUSER_NAME()
         ,EditDate = GetDate()
      WHERE Orderkey = @c_Orderkey

      SET @n_err = @@ERROR
      IF @n_err <> 0
      BEGIN
         SET @n_Continue = 3
         SET @n_err = 30102  
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Cancel Orders. (isp_RemoveMBOLOrders)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT
      END
   END

   DELETE FROM MBOLDETAIL WITH (ROWLOCK)
   WHERE MBOLKey = @c_MBOLKey
   AND   MBOLLineNumber = @c_MBOLlineNumber

   SET @n_err = @@ERROR
   IF @n_err <> 0
   BEGIN
      SET @n_Continue = 3
      SET @n_err = 30102  
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Delete MBOLDetail. (isp_RemoveMBOLOrders)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END

   QUIT:
   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt
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
      execute nsp_logerror @n_err, @c_errmsg, 'isp_RemoveMBOLOrders'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
       COMMIT TRAN
      END
      RETURN
   END      
END

GO