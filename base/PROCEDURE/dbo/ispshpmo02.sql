SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO02                                            */
/* Creation Date: 05-DEC-2013                                              */
/* Copyright: IDS                                                          */
/* Written by: YTWan                                                       */
/*                                                                         */
/* Purpose: Initialize ID.PalletFlag after MBOL Shipped                    */
/*        : SOS#315026 - Project Merlion MBOL Pack and Hold Pallet         */
/*          Selection function                                             */
/*        :                                                                */
/*                                                                         */
/* Called By:                                                              */
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
/* 09-APR-2015  YTWan   1.0   SOS#338644 - Project Merlion - Release Lane  */
/*                            Assigned After MBOL Shipped. (Wan01)         */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO02]  
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
  
   DECLARE @b_Debug     INT
         , @n_Continue  INT 
         , @n_StartTCnt INT 

   DECLARE @c_ID        NVARCHAR(18)
         , @c_Orderkey  NVARCHAR(10)         
     
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
  

   DECLARE CUR_PLT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT DISTINCT PD.ID
         , MD.Orderkey
   FROM MBOLDETAIL MD WITH (NOLOCK)
   JOIN ORDERS     OH WITH (NOLOCK) ON (MD.Orderkey = OH.Orderkey)
   JOIN PICKDETAIL PD WITH (NOLOCK) ON (OH.Orderkey = PD.Orderkey)
   WHERE MD.MBOLKey   = @c_MBOLkey
   AND   OH.Storerkey = @c_Storerkey
  
   OPEN CUR_PLT  
  
   FETCH NEXT FROM CUR_PLT INTO @c_ID
                              , @c_Orderkey 

   WHILE @@FETCH_STATUS <> -1
   BEGIN 
      UPDATE ID WITH (ROWLOCK)
      SET PalletFlag = ''
         ,PalletFlag2= ''
         ,EditWho = SUSER_NAME()
         ,EditDate= GETDATE()
         ,Trafficcop = NULL
      WHERE ID = @c_ID

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE ID Failed. (ispSHPMO02)' 
         GOTO QUIT_SP
      END 

      --(Wan01) - START
      UPDATE LOADPLANLANEDETAIL WITH (ROWLOCK)
      SET Status = '9'
        , EditWho= SUSER_NAME()
        , EditDate=GETDATE()
        , Trafficcop = NULL
      WHERE EXISTS ( SELECT 1
                     FROM ORDERS WITH (NOLOCK)
                     WHERE ORDERS.Orderkey = @c_Orderkey
                     AND   ((ORDERS.Loadkey = LOADPLANLANEDETAIL.Loadkey AND LOADPLANLANEDETAIL.Loadkey <> '')
                     OR     (ORDERS.Mbolkey = LOADPLANLANEDETAIL.MBOLKey AND LOADPLANLANEDETAIL.MBOLKey <> ''))
                   )

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61015   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE LOADPLANDETAIL Failed. (ispSHPMO02)' 
         GOTO QUIT_SP
      END 
      --(Wan01) - END

      FETCH NEXT FROM CUR_PLT INTO @c_ID
                                 , @c_Orderkey
   END
   CLOSE CUR_PLT
   DEALLOCATE CUR_PLT

   QUIT_SP:

   IF CURSOR_STATUS('LOCAL' , 'CUR_PLT') in (0 , 1)
   BEGIN
      CLOSE CUR_PLT
      DEALLOCATE CUR_PLT
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO02'
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