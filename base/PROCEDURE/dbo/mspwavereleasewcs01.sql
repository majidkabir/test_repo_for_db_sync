SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: mspWaveReleaseWCS01                                 */
/* Creation Date: 2024-11-19                                             */
/* Copyright: Maersk                                                     */  
/* Written by: Supriya                                                   */
/*                                                                       */  
/* Purpose: Release to WCS                                               */  
/*                                                                       */  
/* Called By: WMS Wave Release To WCS                                    */
/*                                                                       */  
/* Version: Maserk V2                                                    */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date         Author  Ver   Purposes                                   */ 
/* 2024-11-19   SSA01   1.1   UWP-27112-[LEVI's] Release to WCS Update   */
/* 2024-12-18   SSA02   1.2   UWP-27112-Added automated wave validation  */
/*                            and update tasks status from H to 0        */
/* 2025-01-08   SSA03   1.3   UWP-27112-Added extra logic to update tasks*/
/*                            status from H to 0                         */
/* 2025-01-23   SSA04   1.4   UWP-27112-Added extra logic to update tasks*/
/*                            status from H to 0                         */
/* 2025-02-07   SSA05   1.5   UWP-30025-Update Destination ID before     */
/*                            Releasing to WCS                           */
/* 2025-02-12   SSA06   1.6   UWP-30025- Updated orderinfo.orderinfo09 to*/
/*                            orderinfo.orderinfo06 as per v2.1          */
/*************************************************************************/   
CREATE   PROCEDURE [dbo].[mspWaveReleaseWCS01]
  @c_Wavekey      NVARCHAR(10)  
 ,@b_Success      int        OUTPUT  
 ,@n_Err          int        OUTPUT  
 ,@c_Errmsg       NVARCHAR(250)  OUTPUT  
 AS  
 BEGIN  
    SET NOCOUNT ON   
    SET QUOTED_IDENTIFIER OFF   
    SET ANSI_NULLS OFF   
    SET CONCAT_NULL_YIELDS_NULL OFF  
    
    DECLARE @n_Continue          INT          = 1    
          , @n_StartTCnt         INT          = @@TRANCOUNT       -- Holds the current transaction count
          , @n_Debug             INT          = 0
          , @c_Facility          NVARCHAR(5)  = ''          
          , @c_Storerkey         NVARCHAR(15) = ''
          , @c_TableName         NVARCHAR(30) = ''
          , @c_Key1              NVARCHAR(10) = ''
          , @c_Key2              NVARCHAR(30) = ''
          , @c_Key3              NVARCHAR(20) = ''
          , @c_TransmitBatch     NVARCHAR(30) = ''
          , @c_CfgWCS            NVARCHAR(10) = ''
          , @c_ConditionQuery    NVARCHAR(1000)= ''
          , @c_TMReleaseFlag     NVARCHAR(1)= ''
          , @c_UserDefine09      NVARCHAR(1)= ''   --(SSA02)
          , @c_TaskType          NVARCHAR(10)    --(SSA04)
          , @c_LocationType      NVARCHAR(10)    --(SSA04)
          , @c_TaskDetailKey     NVARCHAR(10)    --(SSA04)
          , @b_IsUpdate          int = 1    --(SSA04)
          , @c_WCSCode           NVARCHAR(30) = ''  --(SSA05)
          , @c_OrderKey          NVARCHAR(10)  --(SSA05)
          , @c_ShipperKey        NVARCHAR(15)  --(SSA05)
          , @c_ConsigneeKey      NVARCHAR(15)  --(SSA05)
          , @b_IsParcel          int = 1    --(SSA05)
          , @c_DestIdListName          NVARCHAR(10) = 'WCSDESTID' --(SSA05)
          , @c_DestIdStorerType        NVARCHAR(30) = '2'  --(SSA05)
          , @CUR_ORDERS          CURSOR --(SSA05)
          , @CUR_TASKDETAIL      CURSOR --(SSA04)


    SELECT TOP 1
             @c_Facility  = O.Facility
           , @c_Storerkey = O.StorerKey
     FROM dbo.WAVEDETAIL WD(NOLOCK)
     JOIN dbo.ORDERS O (NOLOCK) ON O.OrderKey = WD.OrderKey
     WHERE WD.WaveKey = @c_Wavekey

    SELECT @c_TMReleaseFlag = WAVE.TMReleaseFlag, @c_UserDefine09 = WAVE.UserDefine09
                FROM dbo.WAVE WAVE (NOLOCK)
                WHERE WAVE.WaveKey = @c_Wavekey

    IF @c_TMReleaseFlag = 'N'
     BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81010
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave has not been Released.  (mspWaveReleaseWCS01) '
     END
     --(SSA02) start ---
     IF @c_UserDefine09 <> 'Y'
     BEGIN
         SET @n_continue = 3
         SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
         SET @n_err = 81030
         SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave is not Automation.  (mspWaveReleaseWCS01) '
     END
     --(SSA02) end----
     IF @n_Continue IN (1,2)
     BEGIN
        SET @c_TableName = 'WSWAVELOG'
             SET @c_Key1 = @c_Wavekey
             SET @c_Key2 = ''
             SET @c_Key3 = @c_Storerkey

        IF EXISTS ( SELECT 1 FROM TransmitLog2 (NOLOCK) WHERE TableName = @c_TableName
						 AND Key1 = @c_Key1 AND Key2 = @c_Key2 AND Key3 = @c_Key3)
          BEGIN
		          SET @n_continue = 3
              SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
              SET @n_err = 81020
              SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Wave already released to WCS. (mspWaveReleaseWCS01) '
           END
           ----(SSA05) start-----
           IF @n_Continue IN (1,2)
            BEGIN
              IF NOT EXISTS (SELECT 1 FROM ORDERINFO(NOLOCK) oi
               JOIN ORDERS(NOLOCK) o ON o.ORDERKEY = oi.ORDERKEY
               JOIN WAVEDETAIL(NOLOCK) wd ON wd.ORDERKEY = o.ORDERKEY
               WHERE wd.WAVEKEY = @c_Wavekey
						   AND (oi.ORDERINFO06 IS NULL OR oi.ORDERINFO06 = ''))     --(SSA06)
                BEGIN
                  SET @n_continue = 3
                  SET @c_errmsg = CONVERT(NVARCHAR(250),@n_err)
                  SET @n_err = 81021
                  SET @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Cannot Re-release to WCS. (mspWaveReleaseWCS01) '
                END
            END
            ----(SSA05) end -----
           IF @n_Continue IN (1,2)
            BEGIN
               ----(SSA05) start-----
                SET @CUR_ORDERS = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT o.OrderKey,o.ShipperKey,o.ConsigneeKey
                FROM ORDERS(NOLOCK) o
                JOIN ORDERINFO(NOLOCK) oi ON o.Orderkey = oi.OrderKey
                JOIN WAVEDETAIL(NOLOCK) wd ON wd.OrderKey = o.OrderKey
                WHERE wd.WaveKey = @c_Wavekey
                AND o.Storerkey = @c_Storerkey
                AND o.userdefine09 = @c_Wavekey

                OPEN @CUR_ORDERS
                FETCH NEXT FROM @CUR_ORDERS INTO @c_OrderKey,@c_ShipperKey,@c_ConsigneeKey

                WHILE @@FETCH_STATUS <> -1
                BEGIN
                SET  @b_IsParcel = 0

                IF EXISTS(SELECT 1 FROM CODELKUP clu (NOLOCK)
                JOIN STORER s (NOLOCK) ON s.StorerKey = clu.Short
                WHERE s.StorerKey = @c_ShipperKey AND clu.listname = 'WSCourier'
                AND clu.code = 'ECL-1' AND s.type = '7'
                )
                BEGIN
                  SET @b_IsParcel = 1
                END

                IF @b_IsParcel = 1
                BEGIN
                  SELECT @c_WCSCode = clu.Code FROM CODELKUP clu (NOLOCK)
                  JOIN storer s (NOLOCK) ON s.SUSR5 = clu.Short
                  WHERE s.StorerKey = @c_ConsigneeKey AND s.type = @c_DestIdStorerType
                  AND clu.StorerKey = @c_Storerkey AND clu.Code2 = @c_ShipperKey
                  AND clu.LISTNAME = @c_DestIdListName
                END
                ELSE
                BEGIN
                  SELECT @c_WCSCode = clu.Code FROM CODELKUP clu (NOLOCK)
                  JOIN storer s (NOLOCK) ON s.SUSR5 = clu.Short
                  WHERE s.StorerKey = @c_ConsigneeKey AND s.type = @c_DestIdStorerType
                  AND clu.StorerKey = @c_Storerkey
                  AND clu.LISTNAME = @c_DestIdListName
                  AND ISNULL(clu.Code2, '') = ''
                END
                IF (ISNULL(@c_WCSCode, '') = '')
                BEGIN
                  SELECT @c_WCSCode = clu.Code FROM CODELKUP (NOLOCK) clu
                  WHERE clu.LISTNAME = @c_DestIdListName AND clu.Code = 'Default' AND clu.StorerKey = @c_Storerkey
                END

                UPDATE ORDERINFO WITH (ROWLOCK) SET ORDERINFO06 = @c_WCSCode  WHERE ORDERKEY = @c_OrderKey  --(SSA06)

                FETCH NEXT FROM @CUR_ORDERS INTO @c_OrderKey,@c_ShipperKey,@c_ConsigneeKey
                END
                CLOSE @CUR_ORDERS
                DEALLOCATE @CUR_ORDERS

                ----(SSA05) end -----
                ----(SSA02),(SSA03),(SSA04)start-----
                SET @CUR_TASKDETAIL = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                SELECT td.TASKDETAILKEY,loc.LOCATIONTYPE,td.TASKTYPE FROM TASKDETAIL(NOLOCK) td
                JOIN LOC(NOLOCK) loc on td.FROMLOC = loc.LOC
                WHERE td.WAVEKEY = @c_Wavekey AND td.STATUS = 'H'

                OPEN @CUR_TASKDETAIL
                FETCH NEXT FROM @CUR_TASKDETAIL INTO @c_TaskDetailKey,@c_LocationType,@c_TaskType

                WHILE @@FETCH_STATUS <> -1
                BEGIN
                  SET @b_IsUpdate = 1

                  IF('ASTCPK' = @c_TaskType AND 'PICKWCS' <> @c_LocationType)
                  SET @b_IsUpdate = 0

                  IF(@b_IsUpdate = 1)
                  UPDATE TASKDETAIL WITH (ROWLOCK) SET STATUS = '0' WHERE TASKDETAILKEY = @c_TaskDetailKey

                FETCH NEXT FROM @CUR_TASKDETAIL INTO @c_TaskDetailKey,@c_LocationType,@c_TaskType
                END
                CLOSE @CUR_TASKDETAIL
                DEALLOCATE @CUR_TASKDETAIL

               ----(SSA02),(SSA03),(SSA04) end-----
               SET @b_Success = 1
               EXEC dbo.ispGenTransmitLog2
                     @c_TableName   = @c_TableName
                  ,  @c_Key1        = @c_Key1
                  ,  @c_Key2        = @c_Key2
                  ,  @c_Key3        = @c_Key3
                  ,  @c_TransmitBatch = @c_TransmitBatch
                  ,  @b_Success     = @b_Success OUTPUT
                  ,  @n_err         = @n_err OUTPUT
                  ,  @c_errmsg      = @c_errmsg OUTPUT

               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
               END
            END
     END
EXIT_SP:

   IF @n_Continue=3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_Success = 0  
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTCnt  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, "mspWaveReleaseWCS01"
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_Success = 1  
      WHILE @@TRANCOUNT > @n_StartTCnt  
      BEGIN  
         COMMIT TRAN  
      END  
      RETURN  
   END
END --sp end

GO