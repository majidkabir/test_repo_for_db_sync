SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO08                                            */
/* Creation Date: 21-Jan-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:  WLChooi                                                    */
/*                                                                         */
/* Purpose: WMS-16085 - HOM - Update SKUInfo.ExtendedField05 upon MBOL Ship*/
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO08]  
(     @c_MBOLkey     NVARCHAR(10)   
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
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTCnt          INT 

   DECLARE @c_Loadkey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         , @c_Pickslipno      NVARCHAR(10)
         , @c_SKU             NVARCHAR(20)
         , @c_GetStorerkey    NVARCHAR(15)
         
   DECLARE @c_MBOLShipCloseSerialNo NVARCHAR(10) = ''
       
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT @c_Storerkey = Storerkey
      FROM ORDERS (NOLOCK)
      WHERE MBOLKey = @c_MBOLKey
   END
   
   SELECT @c_MBOLShipCloseSerialNo = SValue
   FROM StorerConfig (NOLOCK)
   WHERE StorerKey = @c_Storerkey AND Configkey = 'MBOLShipCloseSerialNo'
   
   --Main Process
   BEGIN TRAN

   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      IF @c_MBOLShipCloseSerialNo = '1'
      BEGIN
         DECLARE CUR_DISCPACKSERIAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT DISTINCT SER.StorerKey, SER.SKU
            FROM MBOLDETAIL MD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
            JOIN SERIALNO SER (NOLOCK) ON  O.Storerkey = SER.Storerkey AND O.Orderkey = SER.OrderKey
            WHERE MD.Mbolkey = @c_MBOLKey
      END
      ELSE
      BEGIN
         DECLARE CUR_DISCPACKSERIAL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
            SELECT DISTINCT SER.StorerKey, SER.SKU
            FROM MBOLDETAIL MD (NOLOCK)
            JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey
            JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey
            JOIN PACKSERIALNO PS (NOLOCK) ON PH.PickSlipNo = PS.PickslipNo AND PH.Storerkey = PS.Storerkey
            JOIN SERIALNO SER (NOLOCK) ON  PS.Storerkey = SER.Storerkey AND PS.SKU = SER.Sku AND PS.SerialNo = SER.SerialNo
            WHERE MD.Mbolkey = @c_MBOLKey AND ISNULL(PS.PICKDETAILKEY, '') = ''
            AND PH.Status = '9'
      END
   END
   
   OPEN CUR_DISCPACKSERIAL  
  
   FETCH NEXT FROM CUR_DISCPACKSERIAL INTO @c_GetStorerkey, @c_SKU

   WHILE @@FETCH_STATUS <> -1 AND @n_continue IN(1,2)
   BEGIN
      UPDATE SKUINFO WITH (ROWLOCK)
      SET ExtendedField05 = 'Y'
        , TrafficCop     = NULL
        , EditWho        = SUSER_SNAME()
        , EditDate       = GETDATE()
      WHERE Storerkey = @c_GetStorerkey AND Sku = @c_SKU
        AND ExtendedField05 <> 'Y'
        
      SELECT @n_err = @@ERROR  
         
      IF @n_err <> 0  
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72500    
         SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                          + ': Update Failed On SKUINFO Table for Storerkey = ' + LTRIM(RTRIM(@c_GetStorerkey)) + ' AND SKU = ' + LTRIM(RTRIM(@c_SKU)) + ' (ispSHPMO08)'   
                          + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
      END 
      
      FETCH NEXT FROM CUR_DISCPACKSERIAL INTO @c_GetStorerkey, @c_SKU
   END
         
QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_DISCPACKSERIAL') IN (0 , 1)
   BEGIN
      CLOSE CUR_DISCPACKSERIAL
      DEALLOCATE CUR_DISCPACKSERIAL   
   END
      
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO08'
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