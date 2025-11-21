SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO06                                            */
/* Creation Date: 12-FEB-2019                                              */
/* Copyright: IDS                                                          */
/* Written by:  WLCHOOI                                                    */
/*                                                                         */
/* Purpose: WMS-7892 - MAST Postmbolship SP                                */
/*        :                                                                */
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
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
/* 2019-0921    TLTING01 1.1  Update Editdate                              */
/* 2021-01-04   WLChooi  1.2  WMS-15780 - Add new process (WL01)           */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO06]  
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

   DECLARE @c_consigneekey    NVARCHAR(30)
         , @c_leadtime        INT
         
         , @c_Facility        NVARCHAR(5)    --WL01
         , @c_DocType         NVARCHAR(10)   --WL01
         , @c_DocStatus       NVARCHAR(50)   --WL01
       
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   SET @c_consigneekey  = ''
   SET @c_leadtime      = 0

   --Find Consigneekey - one mbol has only one consigneekey
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SELECT TOP 1 @c_consigneekey = Orders.Consigneekey
      FROM MBOLDETAIL (NOLOCK)
      JOIN ORDERS (NOLOCK) ON ORDERS.ORDERKEY = MBOLDETAIL.ORDERKEY
      WHERE MBOLDETAIL.MBOLKEY = @c_MBOLkey
   END
   
   --Find Leadtime
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SELECT TOP 1 @c_leadtime = CAST(ISNULL(Short,0) AS INT)
      FROM CODELKUP (NOLOCK)
      WHERE LISTNAME = 'StoreLTime' AND CODE = @c_consigneekey
      AND STORERKEY = @c_storerkey
   END

   --Main Process
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
    --Check first order if it meet the condition
      IF EXISTS(
      SELECT TOP 1 1
      FROM MBOLDETAIL WITH (NOLOCK)
      JOIN ORDERS WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
      WHERE MBOLDETAIL.MBOLKey   = @c_MBOLkey
      AND   ORDERS.Doctype = 'N'
      AND   ORDERS.Type   <> 'MANUAL')
         
      --If exists, update into mbol
      BEGIN
         UPDATE MBOL WITH (ROWLOCK)
         SET PlaceOfDelivery = @c_consigneekey
            ,ArrivalDate     = DATEADD(dd, @c_leadtime, DATEDIFF(dd, 0, GETDATE())) 
            ,EditDate        = getdate()       --tlting01
            ,EditWho         = Suser_Sname()   --tlting01
         WHERE MBOLKey = @c_MBOLkey
         
         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72806    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Update Failed On Table MBOL. (ispSHPMO06)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END  
      END

   --Check first order if it meet the condition
   END
   --Main Process End

   --WL01 - S
   IF(@n_Continue = 1 or @n_Continue = 2)
   BEGIN
      SELECT @c_Facility  = MIN(OH.Facility)
           , @c_DocType   = MIN(OH.DocType)
           , @c_Storerkey = MIN(OH.StorerKey)
      FROM ORDERS OH (NOLOCK)
      WHERE OH.MBOLKey = @c_MBOLkey
      
      DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Code 
      FROM CODELKUP (NOLOCK) 
      WHERE Storerkey = @c_Storerkey AND UDF01 = @c_Facility 
      AND UDF02 = @c_DocType AND code2 = '315'
      AND LISTNAME = 'MBOLSTATRK'
      
      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @c_DocStatus
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
      	IF NOT EXISTS (SELECT 1 FROM DocStatusTrack Dst (NOLOCK) 
      	               WHERE Dst.DocumentNo = @c_MBOLkey AND Dst.StorerKey = @c_Storerkey 
      	               AND Dst.DocStatus = @c_DocStatus AND Dst.TableName = 'MBOL')
      	BEGIN
            INSERT INTO DocStatusTrack (TableName, DocumentNo, StorerKey, DocStatus, Finalized)
            SELECT 'MBOL', @c_MBOLkey, @c_Storerkey, @c_DocStatus, 'Y'
            
            SELECT @n_err = @@ERROR  
            
            IF @n_err <> 0  
            BEGIN
               SELECT @n_continue = 3  
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72810    
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                + ': Failed To Insert Into DocStatusTrack Table. (ispSHPMO06)'   
                                + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
            END
         END
         
         FETCH NEXT FROM CUR_LOOP INTO @c_DocStatus
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END
   --WL01 - E

   QUIT_SP:

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO06'
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