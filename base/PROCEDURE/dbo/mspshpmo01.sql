SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: mspSHPMO01                                            */
/* Creation Date: 2024-12-02                                               */
/* Copyright: IDS                                                          */
/* Written by: Wan                                                         */
/*                                                                         */
/* Purpose: UWP-27569 - [FCR-1178] [JCB] Parent Order Status update        */
/*        :                                                                */
/*                                                                         */
/* Called By:                                                              */
/*                                                                         */
/*                                                                         */
/*                                                                         */
/* Version: 1.0                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE   PROC [dbo].[mspSHPMO01]  
   @c_MBOLkey     NVARCHAR(10)   
,  @c_Storerkey   NVARCHAR(15)
,  @b_Success     INT           = 1    OUTPUT
,  @n_Err         INT           = 0    OUTPUT
,  @c_ErrMsg      NVARCHAR(255) = ''   OUTPUT   
  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT            = 0
         , @n_Continue           INT            = 1
         , @n_StartTCnt          INT            = @@TRANCOUNT
                                        
         , @c_ExternOrderkey     NVARCHAR(50)   = ''
         , @c_Orderkey           NVARCHAR(10)   = ''
         , @c_OrderKey_P         NVARCHAR(10)   = ''
         , @c_OrderLineNumber_P  NVARCHAR(10)   = ''
         , @c_LoadKey_P          NVARCHAR(10)   = ''
         , @c_LoadLineNumber_P   NVARCHAR(10)   = '' 
         , @c_MBOLKey_P          NVARCHAR(10)   = ''
         , @c_Status_C           NVARCHAR(10)   = ''

         , @CUR_ORD              CURSOR
         , @CUR_OD               CURSOR

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''

   IF @@TRANCOUNT = 0
   BEGIN
      BEGIN TRAN
   END

   SET @CUR_ORD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   SELECT O.ExternOrderKey 
   FROM ORDERS o (NOLOCK) 
   JOIN MBOLDETAIL md (NOLOCK) ON md.Orderkey = o.Orderkey
   WHERE md.MbolKey = @c_MBOLkey
   AND o.ExternOrderKey > ''
   GROUP BY O.ExternOrderKey
   ORDER BY MIN(md.MbolLineNumber)
   
   OPEN @CUR_ORD  
  
   FETCH NEXT FROM @CUR_ORD INTO @c_ExternOrderkey 

   WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
   BEGIN
      SET @c_Status_C = '0'
      SELECT TOP 1 @c_Status_C = o.[Status]
      FROM ORDERS o WITH (NOLOCK)  
      WHERE o.ExternOrderKey = @c_ExternOrderkey
      AND o.StorerKey = @c_Storerkey
      AND o.Rdd = 'SplitOrder'      
      ORDER BY o.[Status]

      IF @c_Status_C < '9'
      BEGIN
         GOTO NEXT_CHILD_ORD
      END

      SET @c_OrderKey_P = ''
      SELECT TOP 1 @c_OrderKey_P = o.Orderkey
      FROM ORDERS o WITH (NOLOCK)  
      WHERE o.ExternOrderKey = @c_ExternOrderkey
      AND o.ExternOrderKey > ''
      AND o.StorerKey = @c_Storerkey
      AND o.Rdd <> 'SplitOrder'
      AND o.[Status] < '9'
      ORDER BY o.Orderkey

      IF @c_OrderKey_P <> ''
      BEGIN
         IF NOT EXISTS (SELECT 1 
                        FROM ORDERDETAIL od (NOLOCK)
                        WHERE od.Orderkey = @c_OrderKey_P
                        AND od.OpenQty > 0
                       )
         BEGIN
            SET @CUR_OD = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT od.Orderkey, od.OrderLineNumber
            FROM ORDERDETAIL od WITH (NOLOCK)  
            WHERE od.Orderkey = @c_Orderkey_P
            AND   od.[Status] < '9'
            ORDER BY od.OrderLineNumber
  
            OPEN @CUR_OD  
  
            FETCH NEXT FROM @CUR_OD INTO @c_Orderkey_P, @c_OrderLineNumber_P

            WHILE @@FETCH_STATUS <> -1 AND @n_Continue = 1
            BEGIN 
               UPDATE ORDERDETAIL WITH (ROWLOCK)
               SET [Status]   = '9'
                  ,EditDate = GETDATE()
                  ,EditWho  = SUSER_NAME()  
                  ,TrafficCop= NULL
               WHERE Orderkey = @c_Orderkey_P 
               AND   OrderLineNumber = @c_OrderLineNumber_P

               IF @@ERROR <> 0
               BEGIN
                  SET @n_Continue = 3
               END

               FETCH NEXT FROM @CUR_OD INTO @c_Orderkey_P, @c_OrderLineNumber_P
            END
            CLOSE @CUR_OD
            DEALLOCATE @CUR_OD

            IF @n_Continue = 1
            BEGIN
               IF EXISTS ( SELECT 1 FROM ORDERS O(NOLOCK) WHERE O.Orderkey = @c_Orderkey_P
                           AND O.[Status] < '9'
                         )
               BEGIN 
                  UPDATE ORDERS WITH (ROWLOCK)
                  SET [Status] = '9'
                     ,SOStatus = '9'
                     ,EditDate = GETDATE()
                     ,EditWho  = SUSER_NAME()  
                  WHERE Orderkey = @c_Orderkey_P

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                  END
               END
            END

            IF @n_Continue = 1
            BEGIN
               SELECT @c_LoadKey_P = lpd.LoadKey
                     ,@c_LoadLineNumber_P = lpd.LoadLineNumber
               FROM LoadPlanDetail lpd (NOLOCK) 
               WHERE lpd.OrderKey = @c_Orderkey_P
               AND lpd.[Status] <= '9'

               IF @c_LoadLineNumber_P > ''
               BEGIN
                  UPDATE LoadPlanDetail WITH (ROWLOCK)
                  SET [Status] = '9'
                     ,EditDate = GETDATE()
                     ,EditWho  = SUSER_NAME()  
                     ,TrafficCop= NULL
                  WHERE LoadKey = @c_LoadKey_P 
                  AND   LoadLineNumber = @c_LoadLineNumber_P

                  IF @@ERROR <> 0
                  BEGIN
                     SET @n_Continue = 3
                  END
               END

               IF @n_Continue = 1
               BEGIN
                  IF EXISTS ( SELECT 1
                              FROM LoadPlan lp (NOLOCK) 
                              WHERE lp.LoadKey = @c_LoadKey_P
                              AND lp.[Status] < '9'
                            )
                  BEGIN
                     IF NOT EXISTS (SELECT 1
                                    FROM LoadPlanDetail lpd (NOLOCK) 
                                    WHERE lpd.LoadKey = @c_LoadKey_P
                                    AND lpd.[Status] < '9'
                                    )
                     BEGIN
                        UPDATE LoadPlan WITH (ROWLOCK)
                        SET [Status] = '9'
                           ,EditDate = GETDATE()
                           ,EditWho  = SUSER_NAME()  
                        WHERE LoadKey = @c_LoadKey_P

                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_Continue = 3
                        END
                     END
                  END
               END
            END

            IF @n_Continue = 1
            BEGIN
               SELECT @c_MBOLKey_P = md.MbolKey
               FROM MBOLDETAIL md (NOLOCK) 
               WHERE md.OrderKey = @c_Orderkey_P

               IF @c_MBOLKey_P > ''
               BEGIN
                  IF EXISTS ( SELECT 1
                              FROM MBOL m (NOLOCK) 
                              WHERE m.MBOLKey = @c_MBOLKey_P
                              AND m.[Status] < '9'
                            )
                  BEGIN
                     IF NOT EXISTS (SELECT 1
                                    FROM MBOLDETAIL md (NOLOCK) 
                                    JOIN ORDERS o (NOLOCK) ON o.Orderkey = md.Orderkey
                                    WHERE md.MbolKey = @c_MBOLKey_P
                                    AND o.[Status] < '9'
                                    )
                     BEGIN
                        UPDATE MBOL WITH (ROWLOCK)
                        SET [Status] = '9'
                           ,EditDate = GETDATE()
                           ,EditWho  = SUSER_NAME()  
                        WHERE MBOLKey = @c_MBOLKey_P 
 
                        IF @@ERROR <> 0
                        BEGIN
                           SET @n_Continue = 3
                        END
                     END
                  END
               END
            END
         END
      END
      NEXT_CHILD_ORD:
      FETCH NEXT FROM @CUR_ORD INTO @c_ExternOrderkey 
   END
   CLOSE @CUR_ORD 
   DEALLOCATE @CUR_ORD

   QUIT_SP:
   
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'mspSHPMO01'
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