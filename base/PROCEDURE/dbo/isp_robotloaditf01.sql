SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_RobotLoadITF01                                      */
/* Creation Date: 20-JUN-2018                                           */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose: WMS-5240 - CN_Robot_Exceed_BulidLoad_Order_Trigger          */
/*                                                                      */                                             
/*        :                                                             */
/* Called By: isp_GenEOrder_Replenishment_Wrapper                       */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_RobotLoadITF01]
           @c_Loadkey   NVARCHAR(10) 
         , @b_Success   INT            OUTPUT
         , @n_Err       INT            OUTPUT
         , @c_ErrMsg    NVARCHAR(255)  OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 

         , @c_Facility        NVARCHAR(5)
         , @c_StorerKey       NVARCHAR(15)

         , @c_DocType_Min     CHAR(1)
         , @c_DocType_Max     CHAR(1)
         , @c_OrderMode_Min   CHAR(1)
         , @c_OrderMode_Max   CHAR(1)
         , @c_CSGStatus_Min   NVARCHAR(10)
         , @c_CSGStatus_Max   NVARCHAR(10)

         , @c_TriggerType     NVARCHAR(10)
         , @c_TableName       NVARCHAR(30)
         , @c_RobotLoadITF    NVARCHAR(30)

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue = 1
   SET @n_err      = 0
   SET @c_errmsg   = ''
   SET @c_TableName= 'RBTLOADRCM'

   SET @c_StorerKey = ''
   SET @c_Facility = ''
   SELECT @c_Facility      = LP.Facility
         ,@c_Storerkey     = ISNULL(MAX(OH.Storerkey),'')
         ,@c_DocType_Min   = ISNULL(MIN(OH.DocType),'') 
         ,@c_DocType_Max   = ISNULL(MAX(OH.DocType),'') 
         ,@c_OrderMode_Min = ISNULL(MIN(CASE WHEN OH.OpenQty = 1 THEN 'S' ELSE 'M' END),'')
         ,@c_OrderMode_Max = ISNULL(MAX(CASE WHEN OH.OpenQty = 1 THEN 'S' ELSE 'M' END),'')
         ,@c_CSGStatus_Min = ISNULL(MIN(CASE WHEN OH.DocType = 'N' AND CL.Code IS NOT NULL
                                             THEN 'VIP'
                                             ELSE 'NORMAL'
                                             END),'')
         ,@c_CSGStatus_Max = ISNULL(MAX(CASE WHEN OH.DocType = 'N' AND CL.Code IS NOT NULL
                                             THEN 'VIP'
                                             ELSE 'NORMAL'
                                             END),'')
   FROM LOADPLAN LP WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
   JOIN ORDERS         OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   LEFT JOIN CODELKUP  CL  WITH (NOLOCK) ON (CL.ListName = 'VIPList')
                                         AND(CL.Code = OH.ConsigneeKey)
                                         AND(CL.Storerkey = OH.Storerkey)
   WHERE LP.Loadkey = @c_Loadkey
   GROUP BY LP.Facility

   SET @b_Success = 1
   EXEC nspGetRight  
         @c_Facility            
      ,  @c_StorerKey             
      ,  ''       
      ,  @c_TableName             
      ,  @b_Success        OUTPUT    
      ,  @c_RobotLoadITF   OUTPUT  
      ,  @n_err            OUTPUT  
      ,  @c_errmsg         OUTPUT

   IF @b_Success <> 1
   BEGIN 
      SET @n_Continue= 3    
      SET @n_Err     = 60010    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing nspGetRight: '  
                     + '.(isp_RobotLoadITF01)'
      GOTO QUIT_SP  
   END

   IF @c_RobotLoadITF <> '1'
   BEGIN 
      SET @n_Continue= 3    
      SET @n_Err     = 60020    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Robot Interface Configkey: ' + RTRIM(@c_TableName)  
                     + ' is not turn on.(isp_RobotLoadITF01)' 
      GOTO QUIT_SP  
   END

   SET @c_StorerKey = ''
   SELECT @c_Facility      = LP.Facility
         ,@c_Storerkey     = ISNULL(MAX(OH.Storerkey),'')
         ,@c_DocType_Min   = ISNULL(MIN(OH.DocType),'') 
         ,@c_DocType_Max   = ISNULL(MAX(OH.DocType),'') 
         ,@c_OrderMode_Min = ISNULL(MIN(CASE WHEN OH.OpenQty = 1 THEN 'S' ELSE 'M' END),'')
         ,@c_OrderMode_Max = ISNULL(MAX(CASE WHEN OH.OpenQty = 1 THEN 'S' ELSE 'M' END),'')
         ,@c_CSGStatus_Min = ISNULL(MIN(CASE WHEN OH.DocType = 'N' AND CL.Code IS NOT NULL
                                             THEN 'VIP'
                                             ELSE 'NORMAL'
                                             END),'')
         ,@c_CSGStatus_Max = ISNULL(MAX(CASE WHEN OH.DocType = 'N' AND CL.Code IS NOT NULL
                                             THEN 'VIP'
                                             ELSE 'NORMAL'
                                             END),'')
   FROM LOADPLAN LP WITH (NOLOCK)
   JOIN LOADPLANDETAIL LPD WITH (NOLOCK) ON (LP.Loadkey = LPD.Loadkey)
   JOIN ORDERS         OH  WITH (NOLOCK) ON (LPD.Orderkey = OH.Orderkey)
   LEFT JOIN CODELKUP  CL  WITH (NOLOCK) ON (CL.ListName = 'VIPList')
                                         AND(CL.Code = OH.ConsigneeKey)
                                         AND(CL.Storerkey = OH.Storerkey)
   WHERE LP.Loadkey = @c_Loadkey
   GROUP BY LP.Facility

   IF @c_DocType_Min NOT IN ('E', 'N') OR @c_DocType_Max NOT IN ('E', 'N')
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60030    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid DocType is found in Load'  
                     + '.(isp_RobotLoadITF01)'
      GOTO QUIT_SP  
   END

   IF @c_DocType_Min <> @c_DocType_Max
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60040    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Mixing ECOM and Normal DocType is found in Load'  
                     + '.(isp_RobotLoadITF01)'
      GOTO QUIT_SP  
   END

   IF @c_DocType_Min = 'N'
   BEGIN
      SET @c_OrderMode_Min = '*'
   END
   ELSE
   BEGIN 
      IF @c_OrderMode_Min <> @c_OrderMode_Max
      BEGIN
         SET @n_Continue= 3    
         SET @n_Err     = 60050    
         SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Mixing Single and Multi ECOM order is found in Load '  
                        + '.(isp_RobotLoadITF01)'
         GOTO QUIT_SP  
      END
   END

   IF @c_DocType_Min = 'N' AND @c_CSGStatus_Min <> @c_CSGStatus_Max
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60060    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Mixing VIP and NON VIP for Normal order in Load is found'  
                     + '.(isp_RobotLoadITF01)'
      GOTO QUIT_SP  
   END

   SET @c_TriggerType = ''
   SELECT @c_TriggerType = ISNULL(RTRIM(CL.Short),'')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'RBTORDTYPE'
   AND   CL.UDF01 = @c_DocType_Min
   AND   CL.UDF02 = @c_CSGStatus_Min
   AND   CL.UDF03 = @c_OrderMode_Min

   IF @c_TriggerType = '' OR @c_TriggerType NOT IN ('LOAD', 'ORDER', 'BATCH')
   BEGIN
      SET @n_Continue= 3    
      SET @n_Err     = 60070    
      SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Invalid Interface Trigger Type not found'  
                     + '.(isp_RobotLoadITF01)'
      GOTO QUIT_SP        
   END



   BEGIN TRAN
   IF @c_RobotLoadITF = '1'
   BEGIN
      EXEC ispGenTransmitLog3
         @c_TableName = @c_TableName
      ,  @c_Key1      = @c_Loadkey
      ,  @c_Key2      = @c_TriggerType
      ,  @c_Key3      = @c_StorerKey
      ,  @c_TransmitBatch = ''
      ,  @b_Success       = @b_Success OUTPUT
      ,  @n_err           = @n_err     OUTPUT
      ,  @c_errmsg        = @c_errmsg  OUTPUT

      IF @b_Success <> 1 
      BEGIN 
         SET @n_Continue= 3    
         SET @n_Err     = 60080    
         SET @c_ErrMsg  = 'NSQL'+CONVERT(NVARCHAR(5),@n_Err)+': Error Executing ispGenTransmitLog3 ' 
                        + '.(isp_RobotLoadITF01) ( SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg)+ ' )' 
         GOTO QUIT_SP  
      END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RobotLoadITF01'
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