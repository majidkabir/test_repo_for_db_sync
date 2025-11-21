SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_UnPlanNonFullAllocateOrder                     */  
/* Creation Date: 14-Jan-2020                                           */  
/* Copyright: LFL                                                       */  
/* Written by: WLChooi                                                  */  
/*                                                                      */  
/* Purpose: WMS-11641 - Remove Non-Fully Allocated Orders               */  
/*                                                                      */
/* Called By: Packing                                                   */  
/*                                                                      */  
/* GitLab Version: 1.1                                                  */  
/*                                                                      */  
/* Version: 7.0                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date         Author   Ver  Purposes                                  */  
/* 01-Jun-2020  WLChooi  1.1  Fix Typo (WL01)                           */
/************************************************************************/   
CREATE PROCEDURE [dbo].[isp_UnPlanNonFullAllocateOrder]  
   @c_Sourcekey                  NVARCHAR(4000),
   @c_CallFrom                   NVARCHAR(50),
   @c_OrderStatusToRemove        NVARCHAR(10) = '0,1', --By default, remove orders with status 0,1          
   @n_TotalOrdersRemoved         INT           OUTPUT,
   @b_Success                    INT           OUTPUT,
   @n_Err                        INT           OUTPUT, 
   @c_ErrMsg                     NVARCHAR(250) OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON   
   SET QUOTED_IDENTIFIER OFF   
   SET ANSI_NULLS OFF   
   SET CONCAT_NULL_YIELDS_NULL OFF  
   
   DECLARE @n_continue        INT
         , @c_SQL             NVARCHAR(MAX)
         , @n_StartTCnt       INT
         , @c_SQLArgument     NVARCHAR(4000) 
         , @c_Orderkey        NVARCHAR(10)
         , @c_SPCode          NVARCHAR(30)
         , @c_GetSourcekey    NVARCHAR(10)
         , @c_GetOrderkey     NVARCHAR(10)
         , @c_Facility        NVARCHAR(10)
         , @c_StorerKey       NVARCHAR(15)
         , @c_Configkey       NVARCHAR(20) = 'OrderStatusToRemove'
         , @c_Option1         NVARCHAR(20)  
         , @c_authority       NVARCHAR(10)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @n_TotalOrdersRemoved = 0
   SET @c_GetSourcekey = ''
   SET @c_GetOrderkey = ''

   IF ISNULL(@c_OrderStatusToRemove,'') = '' SET @c_OrderStatusToRemove = '0,1'

   IF @c_CallFrom = 'LOAD'
   BEGIN
      SELECT TOP 1 @c_Facility  = ORDERS.Facility
                 , @c_StorerKey = ORDERS.Storerkey
      FROM ORDERS (NOLOCK)
      JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.Orderkey = ORDERS.Orderkey   --WL01
      WHERE LOADPLANDETAIL.Loadkey = @c_Sourcekey
   END
   ELSE IF @c_CallFrom = 'WAVE'
   BEGIN
      SELECT TOP 1 @c_Facility  = ORDERS.Facility
                 , @c_StorerKey = ORDERS.Storerkey
      FROM ORDERS (NOLOCK)
      JOIN WAVEDETAIL (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey
      WHERE WAVEDETAIL.Wavekey = @c_Sourcekey
   END

   EXECUTE nspGetRight                                
    @c_Facility  = @c_facility,                     
    @c_StorerKey = @c_StorerKey,                    
    @c_sku       = '',
    @c_ConfigKey = @c_Configkey,
    @b_Success   = @b_success   OUTPUT,             
    @c_authority = @c_authority OUTPUT,             
    @n_err       = @n_err       OUTPUT,             
    @c_errmsg    = @c_errmsg    OUTPUT,             
    @c_Option1   = @c_Option1   OUTPUT   
    
   IF @c_authority = '1' AND ISNULL(@c_Option1,'') <> ''
   BEGIN
      SET @c_OrderStatusToRemove = @c_Option1   
   END

   WHILE @@TRANCOUNT > 0
   BEGIN 
      COMMIT TRAN
   END

   BEGIN TRAN

   SELECT @n_err=0, @b_success=1, @c_errmsg='', @n_continue = 1   
   
   CREATE TABLE #TEMP_SOURCEKEY(
      Sourcekey   NVARCHAR(10)
   )

   CREATE TABLE #TEMP_ORDERS(
      Sourcekey  NVARCHAR(10),
      Orderkey   NVARCHAR(10),
      [Status]   NVARCHAR(10)
   )   

   CREATE TABLE #StatusToRemove(
      [Status]   NVARCHAR(10)
   )

   INSERT INTO #TEMP_SOURCEKEY
   SELECT ColValue FROM dbo.fnc_delimsplit (',',@c_Sourcekey) 

   INSERT INTO #StatusToRemove
   SELECT ColValue FROM dbo.fnc_delimsplit (',',@c_OrderStatusToRemove) 

   IF @c_CallFrom = 'LOAD'
   BEGIN
      INSERT INTO #TEMP_ORDERS
      SELECT DISTINCT LPD.Loadkey, OH.Orderkey, OH.[Status]
      FROM ORDERS OH (NOLOCK)
      JOIN LoadPlanDetail LPD (NOLOCK) ON OH.Orderkey = LPD.Orderkey
      JOIN #TEMP_SOURCEKEY t (NOLOCK) ON LPD.Loadkey = t.Sourcekey
      WHERE OH.[Status] IN (SELECT DISTINCT [Status] FROM #StatusToRemove)
   END
   ELSE IF @c_CallFrom = 'WAVE'
   BEGIN
      INSERT INTO #TEMP_ORDERS
      SELECT DISTINCT WD.Wavekey, OH.Orderkey, OH.[Status]
      FROM ORDERS OH (NOLOCK)
      JOIN WAVEDETAIL WD (NOLOCK) ON OH.Orderkey = WD.Orderkey
      JOIN #TEMP_SOURCEKEY t (NOLOCK) ON WD.Wavekey = t.Sourcekey
      WHERE OH.[Status] IN (SELECT DISTINCT [Status] FROM #StatusToRemove)
   END

   DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Sourcekey, Orderkey
   FROM #TEMP_ORDERS

   --Delete Orderkey From Load/Wave
   IF @c_CallFrom = 'LOAD'
   BEGIN
      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_GetSourcekey, @c_GetOrderkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         
         DELETE FROM LoadPlanDetail
         WHERE LoadKey = @c_GetSourcekey AND Orderkey = @c_GetOrderkey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63300    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting from LoadPlanDetail table. (isp_UnPlanNonFullAllocateOrder)'
            GOTO QUIT_SP    
         END

         SET @n_TotalOrdersRemoved = @n_TotalOrdersRemoved + 1

         FETCH NEXT FROM CUR_LOOP INTO @c_GetSourcekey, @c_GetOrderkey
      END
   END
   ELSE IF @c_CallFrom = 'WAVE'
   BEGIN
      OPEN CUR_LOOP

      FETCH NEXT FROM CUR_LOOP INTO @c_GetSourcekey, @c_GetOrderkey
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         
         DELETE FROM WAVEDETAIL
         WHERE Wavekey = @c_GetSourcekey AND Orderkey = @c_GetOrderkey

         IF @@ERROR <> 0
         BEGIN
            SELECT @n_Continue = 3    
            SELECT @n_Err = 63305    
            SELECT @c_ErrMsg='NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error while deleting from WAVEDETAIL table (isp_UnPlanNonFullAllocateOrder)'
            GOTO QUIT_SP    
         END

         SET @n_TotalOrdersRemoved = @n_TotalOrdersRemoved + 1

         FETCH NEXT FROM CUR_LOOP INTO @c_GetSourcekey, @c_GetOrderkey
      END
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_LOOP') in (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

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
      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_UnPlanNonFullAllocateOrder'
   END
   ELSE
   BEGIN
      SET @b_Success = @n_Continue
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END
    
END  

GO