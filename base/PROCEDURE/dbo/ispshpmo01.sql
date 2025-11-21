SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO01                                            */
/* Creation Date: 05-DEC-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: SOS#294825- ANF Create MBOL                                    */
/*        :                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/* PVCS Version: 1.1                                                       */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 12-JUN-2014  YTWan   1.1   Enhance retail process to handle shortpick   */
/*                            parent Order (Wan01)                         */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO01]  
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

   DECLARE @n_PStatusCnt         INT 
         , @n_PLoadStatusCnt     INT 
    
         , @c_Orderkey           NVARCHAR(10)
     
         , @c_POrderKey          NVARCHAR(10)
         , @c_POrderLineNumber   NVARCHAR(5) 
         , @c_PStatus            NVARCHAR(10)

         , @c_PLoadKey           NVARCHAR(10) 
         , @c_PLoadStatus        NVARCHAR(10)

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  
   SET @n_PStatusCnt    = 0
   SET @n_PLoadStatusCnt= 0
   SET @c_POrderKey     = ''
   SET @c_PStatus       = ''
   SET @c_PLoadKey      = ''
   SET @c_PLoadStatus   = ''


   DECLARE CUR_ORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT OH.Orderkey
   FROM MBOLDETAIL MD WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   WHERE MD.MBOLKey   = @c_MBOLkey
   AND   OH.Storerkey = @c_Storerkey
  
   OPEN CUR_ORD  
  
   FETCH NEXT FROM CUR_ORD INTO @c_Orderkey

   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      -- GET SPLIT ORDER
   
      DECLARE CUR_PARENTORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      --(Wan01) - START  
      SELECT DISTINCT POrderkey = ISNULL(RTRIM(OD.UserDefine09),'')
      --SELECT POrderkey = ISNULL(RTRIM(OD.UserDefine09),'')
      --     , POrderLineNumber = ISNULL(RTRIM(OD.UserDefine10),'')
      --(Wan01) - END 
      FROM ORDERS      OH WITH (NOLOCK)
      JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
      WHERE OH.Orderkey = @c_Orderkey
      AND   OH.Status   = '9'
      AND   OH.RDD      = 'SplitOrder'
      AND ISNULL(RTRIM(OD.UserDefine09),'') <> ''
      ORDER BY ISNULL(RTRIM(OD.UserDefine09),'')
     
      OPEN CUR_PARENTORD  
     
      FETCH NEXT FROM CUR_PARENTORD INTO @c_POrderkey
                                       --, @c_POrderLineNumber    --(Wan01)

      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         --(Wan01) - START
         --IF EXISTS (SELECT 1
         --           FROM ORDERDETAIL WITH (NOLOCK)
         --           WHERE Orderkey = @c_POrderkey
         --           AND Openqty > 0)
         IF EXISTS (SELECT 1
                    FROM PICKDETAIL WITH (NOLOCK)
                    WHERE Orderkey = @c_POrderkey
                    AND Qty > 0
                    AND (Status < '9' OR ShipFlag <> 'Y'))
         --(Wan01) - END
         BEGIN
            GOTO NEXT_PARENTORD
         END

         IF EXISTS (SELECT 1
                    FROM ORDERDETAIL OD WITH (NOLOCK)
                    JOIN MBOL        MH WITH (NOLOCK) ON (OD.MBOLKey = MH.MBOLKey)
                    WHERE OD.UserDefine09 = @c_POrderkey
                    AND   MH.MBOLKey <> @c_MBOLkey
                    AND   MH.Status < '9'
                    AND   OD.StorerKey = @c_Storerkey ) 
         BEGIN
            GOTO NEXT_PARENTORD
         END

         SET @n_PStatusCnt  = 0
         SET @c_PStatus     = ''

         UPDATE ORDERDETAIL WITH (ROWLOCK)
         SET Status   = '9'
            ,EditDate = GETDATE()
            ,EditWho  = SUSER_NAME()  
            ,TrafficCop= NULL
         WHERE Orderkey = @c_POrderkey
         --AND   OrderLineNumber = @c_POrderLineNumber   --(Wan01)

         IF @@ERROR <> 0  
         BEGIN  
            SET @n_Continue = 3  
            SET @c_ErrMsg = 'Update Orderdetail Table Failed'  
            GOTO QUIT_SP  
         END

         SELECT @n_PStatusCnt = COUNT(DISTINCT OD.Status)
               ,@c_PStatus    = MAX(OD.Status)
               ,@c_PLoadkey   = MAX(OH.Loadkey)
         FROM ORDERS      OH WITH (NOLOCK)
         JOIN ORDERDETAIL OD WITH (NOLOCK) ON (OH.Orderkey = OD.Orderkey)
         WHERE OH.Orderkey = @c_POrderkey

         IF @c_PStatus = '9' AND @n_PStatusCnt = 1
         BEGIN
            UPDATE ORDERS WITH (ROWLOCK)
            SET Status   = '9'
               ,SOStatus = '9'
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_NAME()  
               ,TrafficCop= NULL
            WHERE Orderkey = @c_POrderkey

            IF @@ERROR <> 0   
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Update Orders Table Failed'  
               GOTO QUIT_SP  
            END

            UPDATE LOADPLANDETAIL WITH (ROWLOCK)
            SET Status   = '9'
               ,EditDate = GETDATE()
               ,EditWho  = SUSER_NAME()  
               ,TrafficCop= NULL
            WHERE Orderkey = @c_POrderkey

            IF @@ERROR <> 0  
            BEGIN  
               SET @n_Continue = 3  
               SET @c_ErrMsg = 'Update LoadPlanDetail Table Failed'  
               GOTO QUIT_SP  
            END

            SET @n_PStatusCnt  = 0
            SET @c_PLoadStatus = ''
           
            SELECT @n_PLoadStatusCnt = COUNT(DISTINCT LPD.Status)
                  ,@c_PLoadStatus    = MAX(LPD.Status)
            FROM LOADPLANDETAIL LPD WITH (NOLOCK) 
            WHERE LPD.Loadkey = @c_PLoadkey
            

            IF @c_PLoadStatus = '9' AND @n_PLoadStatusCnt = 1
            BEGIN
               UPDATE LOADPLAN WITH (ROWLOCK)
               SET Status   = '9'
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_NAME()  
                  ,TrafficCop= NULL
               WHERE LoadKey = @c_PLoadkey

               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @c_ErrMsg = 'Update LoadPlan Table Failed'  
                  GOTO QUIT_SP  
               END

               UPDATE LOADPLANLANEDETAIL WITH (ROWLOCK)
               SET Status   = '9'
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_NAME()  
                  ,TrafficCop= NULL
               WHERE LoadKey = @c_PLoadkey

               IF @@ERROR <> 0  
               BEGIN  
                  SET @n_Continue = 3  
                  SET @c_ErrMsg = 'Update LoadPlanLaneDetail Table Failed'  
                  GOTO QUIT_SP  
               END
            END
         END
         NEXT_PARENTORD:
         FETCH NEXT FROM CUR_PARENTORD INTO @c_POrderkey
                                          --, @c_POrderLineNumber    --(Wan01) 
      END
      CLOSE CUR_PARENTORD
      DEALLOCATE CUR_PARENTORD

      NEXT_ORDER:
      FETCH NEXT FROM CUR_ORD INTO @c_Orderkey
   END
   CLOSE CUR_ORD
   DEALLOCATE CUR_ORD

   QUIT_SP:
   IF CURSOR_STATUS('LOCAL' , 'CUR_PARENTORD') in (0 , 1)
   BEGIN
      CLOSE CUR_PARENTORD
      DEALLOCATE CUR_PARENTORD
   END

   IF CURSOR_STATUS('LOCAL' , 'CUR_ORD') in (0 , 1)
   BEGIN
      CLOSE CUR_ORD
      DEALLOCATE CUR_ORD
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO01'
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