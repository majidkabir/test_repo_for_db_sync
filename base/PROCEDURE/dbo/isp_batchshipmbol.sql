SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Trigger: isp_BatchShipMBOL                                           */
/* Creation Date: 29-APR-2015                                           */
/* Copyright: LF Logistics                                              */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: Job scheduler to ship mbol when mbol.status = '7'           */
/*        : SOS#339247 - LFLHK - Maxim Auto MBOL                        */
/* Called By:                                                           */
/*          : Job Scheduler                                             */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 6.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/************************************************************************/
CREATE PROC [dbo].[isp_BatchShipMBOL] 
      @c_storerkey NVARCHAR(15)
AS
BEGIN
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @b_Success         INT 
         , @n_err             INT 
         , @c_errmsg          NVARCHAR(255) 
         , @c_MBOLKey         NVARCHAR(10)

         , @n_DelDayLeftToMBOL   INT 
         , @n_DelDayLeft         INT

   SET @n_StartTCnt = @@TRANCOUNT
   SET @n_Continue  = 1

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END 

   SELECT @n_DelDayLeftToMBOL = ISNULL(CL.Short,'0')
   FROM CODELKUP CL WITH (NOLOCK)
   WHERE CL.ListName = 'BATSHPCFG'
   AND   CL.Code = 'DelDayLeftToMBOL'
   AND   CL.Storerkey = @c_Storerkey
  
   DECLARE CUR_MBOL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT DISTINCT MBOL.MBOLKey
         , DATEDIFF(dd, GETDATE(), MBOL.Arrivaldatefinaldestination)
   FROM MBOL WITH (NOLOCK)
   JOIN MBOLDETAIL WITH (NOLOCK) ON (MBOL.MBOLKey = MBOLDETAIL.MBOLKey)
   JOIN ORDERS     WITH (NOLOCK) ON (MBOLDETAIL.Orderkey = ORDERS.Orderkey)
   WHERE ORDERS.Storerkey = @c_Storerkey
   AND   MBOL.Status = '7'

   OPEN CUR_MBOL

   FETCH NEXT FROM CUR_MBOL INTO  @c_MBOLKey
                                 ,@n_DelDayLeft        
 
   WHILE @@FETCH_STATUS <> -1
   BEGIN

      IF @n_DelDayLeft > @n_DelDayLeftToMBOL
      BEGIN
         GOTO NEXT_MBOL
      END

      SET @b_Success = 0
      SET @n_err = 0
      SET @c_errmsg = ''

      EXEC isp_ShipMBOL
            @c_MBOLKey = @c_MBOLKey
         ,  @b_Success = @b_Success OUTPUT
         ,  @n_err     = @n_err     OUTPUT
         ,  @c_errmsg  = @c_errmsg  OUTPUT


      IF @n_err <> 0 
      BEGIN
         SET @n_Continue  = 3
         SET @n_err = 61005   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Execute isp_ShipMBOL Failed. (isp_BatchShipMBOL) ' 
                      + @c_errmsg
         GOTO NEXT_MBOL
      END
       
      BEGIN TRAN
      UPDATE MBOL WITH (ROWLOCK)
      SET  Status = '9'
      WHERE MBOLKey = @c_MBOLKey 

      SET @n_err = @@ERROR   

      IF @n_err <> 0    
      BEGIN  
         SET @n_continue = 3    
         SET @n_err = 61010   -- Should Be Set To The SQL Errmessage but I don't know how to do so.    
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Update MBOL Failed. (isp_BatchShipMBOL)' 
         GOTO NEXT_MBOL
      END  
      
      NEXT_MBOL:
      IF @n_Continue = 1 OR @n_Continue = 2
      BEGIN
         WHILE @@TRANCOUNT > 0
         BEGIN
            COMMIT TRAN 
         END
      END
      ELSE 
      BEGIN  
         IF @@TRANCOUNT > 0
         BEGIN
            ROLLBACK TRAN 
         END
         EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_BatchShipMBOL'
      END

      FETCH NEXT FROM CUR_MBOL INTO  @c_MBOLKey
                                    ,@n_DelDayLeft  
   END
   CLOSE CUR_MBOL
   DEALLOCATE CUR_MBOL

   QUIT_SP:
   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END 

   RETURN
END -- procedure

GO