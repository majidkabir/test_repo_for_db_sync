SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF11                                            */
/* Creation Date: 03-Jul-2019                                              */
/* Copyright: LFL                                                          */
/* Written by:                                                             */
/*                                                                         */
/* Purpose: WMS-9396 SG THG pack confirm process                           */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
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
/* 16-Aug-2019  NJOW01  1.0   WMS-10048 add m_company                      */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF11]  
(     @c_PickSlipNo  NVARCHAR(10)   
  ,   @c_Storerkey   NVARCHAR(15)
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
  
   DECLARE @b_Debug           INT
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
 
   DECLARE @c_Orderkey        NVARCHAR(10)
         , @c_Country         NVARCHAR(30)
         , @c_TrackingNo      NVARCHAR(30)
         , @c_M_Company       NVARCHAR(45) --NJOW01
            
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug  = 0 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   IF @@TRANCOUNT = 0
      BEGIN TRAN

   SELECT @c_TrackingNo = O.TrackingNo,
          @c_Country = ISNULL(O.c_Country,''),
          @c_Storerkey = O.Storerkey,
          @c_Orderkey = O.Orderkey,
          @c_M_Company = ISNULL(O.M_Company,'') --NJOW01
   FROM PICKHEADER PH (NOLOCK)
   JOIN ORDERS O (NOLOCK) ON PH.Orderkey = O.Orderkey
   WHERE PH.Pickheaderkey = @c_Pickslipno
  
   IF @n_continue IN(1,2)
   BEGIN
      UPDATE ORDERS WITH (ROWLOCK)
      SET SOStatus = '5'
      WHERE Orderkey = @c_Orderkey
      
      SET @n_Err = @@ERROR
                          
      IF @n_Err <> 0
      BEGIN
          SELECT @n_Continue = 3 
          SELECT @n_Err = 38010
          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update ORDERS Table Failed. (ispPAKCF11)'
      END       
   END     
   
   IF @n_continue IN(1,2)
   BEGIN
      EXEC dbo.ispGenTransmitLog2 'WSSOCFMLOG', @c_OrderKey, '0', @c_StorerKey, ''
          , @b_success OUTPUT
          , @n_err OUTPUT
          , @c_errmsg OUTPUT
          
      IF @b_success <> 1
      BEGIN
          SELECT @n_Continue = 3 
          SELECT @n_Err = 38020
          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Generate pack confirm transmitlog2 Failed. (ispPAKCF11)'
      END            
   END               
   
   IF @n_continue IN(1,2)
   BEGIN     
      UPDATE PACKDETAIL WITH (ROWLOCK)
      SET RefNo = @c_TrackingNo,
          RefNo2 = RTRIM(@c_country) + @c_M_Company,  --NJOW01
          ArchiveCop = NULL
      WHERE Pickslipno = @c_Pickslipno
      
      SET @n_Err = @@ERROR                                                                                 
                                                                                                           
	    IF @n_Err <> 0                                                                                       
      BEGIN                                                                                                
          SELECT @n_Continue = 3                                                                           
          SELECT @n_Err = 38030                                                                            
          SELECT @c_Errmsg='NSQL'+CONVERT(varchar(5),@n_Err)+': Update PACKDETAIL Table Failed. (ispPAKCF11)'
      END                
   END 
                                                                                                                                
   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF11'
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