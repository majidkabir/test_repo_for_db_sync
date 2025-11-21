SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispPAKCF19                                            */
/* Creation Date: 03-Mar-2022                                              */
/* Copyright: LFL                                                          */
/* Written by: WLChooi                                                     */
/*                                                                         */
/* Purpose: WMS-19068 - SG EDR Update Packinfo.Trackingno, Packdetail.Refno*/ 
/*                      and Orders.Trackingno upon Pack Confirm            */
/*                                                                         */
/* Called By: PostPackConfirmSP                                            */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 03-Mar-2022  WLChooi 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispPAKCF19]  
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
  
   DECLARE @b_Debug           INT = 0
         , @n_Continue        INT 
         , @n_StartTCnt       INT 
 
   DECLARE @c_ExternOrderkey  NVARCHAR(50)
         , @n_CartonNo        INT
         , @c_TrackingNo      NVARCHAR(50)
         , @c_Orderkey        NVARCHAR(10)
         , @n_Count           INT = 0
         , @c_Conso           NVARCHAR(1) = 'N'
         , @c_UserDefine01    NVARCHAR(10) = ''
   
   IF @n_Err > 0
   BEGIN
      SET @b_Debug  = @n_Err
   END

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   IF @@TRANCOUNT = 0
      BEGIN TRAN 
   
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      CREATE TABLE #TMP_ORDERS (
         Orderkey          NVARCHAR(10)
       , TrackingNo        NVARCHAR(50)
      )
   END
   
   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      SELECT @n_Count = COUNT(OH.OrderKey)
      FROM PACKHEADER PH (NOLOCK)
      JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
      WHERE PH.PickSlipNo = @c_Pickslipno
      
      IF ISNULL(@n_Count,0) = 0 
      BEGIN
         SELECT @n_Count = COUNT(OH.OrderKey)
         FROM PACKHEADER PH (NOLOCK)
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.Orderkey
         WHERE PH.PickSlipNo = @c_Pickslipno

         IF @n_Count > 0
         BEGIN
            SET @c_Conso = 'Y'
         END
      END
   END

   IF (@n_Continue = 1 OR @n_Continue = 2)
   BEGIN
      IF @c_Conso = 'Y'   --Conso
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT OH.OrderKey, PD.CartonNo, OH.ExternOrderKey
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         JOIN PACKINFO PIF (NOLOCK) ON PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo
         JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.LoadKey = PH.LoadKey
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.Orderkey
         WHERE PD.PickSlipNo = @c_PickSlipNo
         AND ISNULL(PIF.TrackingNo,'') = ''
         ORDER BY OH.OrderKey, PD.CartonNo
      END
      ELSE   --Discrete
      BEGIN
         DECLARE CUR_LOOP CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT OH.OrderKey, PD.CartonNo, OH.ExternOrderKey
         FROM PACKHEADER PH (NOLOCK)
         JOIN PACKDETAIL PD (NOLOCK) ON PH.PickSlipNo = PD.PickSlipNo
         JOIN PACKINFO PIF (NOLOCK) ON PD.PickSlipNo = PIF.PickSlipNo AND PD.CartonNo = PIF.CartonNo
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = PH.Orderkey
         WHERE PD.PickSlipNo = @c_PickSlipNo
         AND ISNULL(PIF.TrackingNo,'') = ''
         ORDER BY OH.OrderKey, PD.CartonNo
      END

      OPEN CUR_LOOP
      
      FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @n_CartonNo, @c_ExternOrderkey
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         UPDATE PACKINFO
         SET TrackingNo = @c_ExternOrderkey
         WHERE PickSlipNo = @c_PickSlipNo
         AND CartonNo = @n_CartonNo
      
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 65325     
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PACKINFO table FAILED. (ispPAKCF19)'     
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
            GOTO QUIT_SP    
         END  
      
         UPDATE PACKDETAIL
         SET RefNo = @c_ExternOrderkey
         WHERE PickSlipNo = @c_PickSlipNo
         AND CartonNo = @n_CartonNo
      
         IF @@ERROR <> 0  
         BEGIN  
            SET @n_continue = 3    
            SET @n_err = 65330     
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update PACKDETAIL table FAILED. (ispPAKCF19)'     
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
            GOTO QUIT_SP    
         END  

         IF NOT EXISTS (SELECT 1 FROM #TMP_ORDERS TOR WHERE TOR.Orderkey = @c_Orderkey)
         BEGIN
            UPDATE ORDERS
            SET TrackingNo = @c_ExternOrderkey
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
            WHERE OrderKey = @c_Orderkey
            
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 65335     
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update ORDERS table FAILED. (ispPAKCF19)'     
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
               GOTO QUIT_SP    
            END 

            INSERT INTO #TMP_ORDERS(Orderkey, TrackingNo)
            SELECT @c_Orderkey, @c_ExternOrderkey
         END

         --Update Orders.UserDefine01
         --Actual Logic
         --Tier 1   LESS THAN 4KG  OR LESS THAN 800MM
         --Tier 2   4.01KG TO 10KG OR 800MM <Y<1201MM
         --Tier 3   10.01KG - 20KG OR 1200MM<Y<2000.1MM
         --Tier 4   >20 KG         OR >2000MM
         
         SELECT @c_UserDefine01 = CASE WHEN SUM([Weight]) < 4 THEN CASE WHEN (SUM(CartonLength) + 38 + 12) < 80 THEN 'TIER 1'
                                                                        WHEN (SUM(CartonLength) + 38 + 12) BETWEEN 80 AND 120 THEN 'TIER 2'
                                                                        WHEN (SUM(CartonLength) + 38 + 12) BETWEEN 120 AND 200 THEN 'TIER 3'
                                                                        WHEN (SUM(CartonLength) + 38 + 12) > 200 THEN 'TIER 4' END
                                       WHEN SUM([Weight]) BETWEEN 4 AND 10 THEN CASE WHEN (SUM(CartonLength) + 38 + 12) < 120 THEN 'TIER 2'
                                                                                     WHEN (SUM(CartonLength) + 38 + 12) BETWEEN 120 AND 200 THEN 'TIER 3'
                                                                                     WHEN (SUM(CartonLength) + 38 + 12) > 200 THEN 'TIER 4' END
                                       WHEN SUM([Weight]) BETWEEN 10 AND 20 THEN CASE WHEN (SUM(CartonLength) + 38 + 12) > 200 THEN 'TIER 4' ELSE 'TIER 3' END
                                       WHEN SUM([Weight]) > 20 OR (SUM(CartonLength) + 38 + 12) > 200 THEN 'TIER 4'
                                       ELSE '' END
         FROM PACKINFO PFO (NOLOCK)
         JOIN PACKHEADER PH (NOLOCK) ON PH.PickSlipNo = PFO.PickSlipNo
         JOIN STORER ST (NOLOCK) ON ST.StorerKey = PH.StorerKey
         JOIN CARTONIZATION CN (NOLOCK) ON ST.CartonGroup = CN.CartonizationGroup AND CN.CartonType = PFO.CartonType
         WHERE PFO.PickSlipNo = @c_PickSlipNo
         
         IF ISNULL(@c_UserDefine01,'') <> ''
         BEGIN
            UPDATE ORDERS
            SET UserDefine01 = @c_UserDefine01
              , TrafficCop = NULL
              , EditDate   = GETDATE()
              , EditWho    = SUSER_SNAME()
            WHERE OrderKey = @c_Orderkey
            
            IF @@ERROR <> 0  
            BEGIN  
               SET @n_continue = 3    
               SET @n_err = 65340   
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Update ORDERS table FAILED. (ispPAKCF19)'     
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '     
               GOTO QUIT_SP    
            END 
         END
      
         FETCH NEXT FROM CUR_LOOP INTO @c_Orderkey, @n_CartonNo, @c_ExternOrderkey
      END
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP
   END

QUIT_SP:
   IF CURSOR_STATUS('LOCAL', 'CUR_LOOP') IN (0 , 1)
   BEGIN
      CLOSE CUR_LOOP
      DEALLOCATE CUR_LOOP   
   END

   IF OBJECT_ID('tempdb..#TMP_ORDERS') IS NOT NULL
      DROP TABLE #TMP_ORDERS
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispPAKCF19'
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