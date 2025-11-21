SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: isp_RCM_REPL_Dyson_VoicePick                        */  
/* Creation Date: 2022-08-01                                             */  
/* Copyright: LFL                                                        */  
/* Written by: Wan                                                       */  
/*                                                                       */  
/* Purpose: LFWM-3641 -  [CN] DYSON Voice Picking replenishment trigger  */
/*          button New                                                   */
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.0                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */
/* 2022-08-01  Wan      1.0   Created & DevOps Combine Script            */
/*************************************************************************/   
CREATE PROC [dbo].[isp_RCM_REPL_Dyson_VoicePick]  
   @c_Storerkey            NVARCHAR(15)
,  @c_Facility             NVARCHAR(5) 
,  @c_ReplGroup            NVARCHAR(10) = 'ALL'
,  @c_Zone02               NVARCHAR(10) = ''
,  @c_Zone03               NVARCHAR(10) = ''
,  @c_Zone04               NVARCHAR(10) = ''
,  @c_Zone05               NVARCHAR(10) = ''
,  @c_Zone06               NVARCHAR(10) = ''
,  @c_Zone07               NVARCHAR(10) = ''
,  @c_Zone08               NVARCHAR(10) = ''
,  @c_Zone09               NVARCHAR(10) = ''
,  @c_Zone10               NVARCHAR(500)= ''         
,  @c_Zone11               NVARCHAR(500)= ''         
,  @c_Zone12               NVARCHAR(10) = ''
,  @b_Success              INT          = 1   OUTPUT   
,  @n_Err                  INT          = 0   OUTPUT
,  @c_Errmsg               NVARCHAR(255)= ''  OUTPUT
,  @c_Code                 NVARCHAR(30) = ''           
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue           INT = 1
         , @n_StartTCnt          INT = @@TRANCOUNT
         
         , @c_TableName          NVARCHAR(30) = 'WSVPREPLOG'
         , @c_WSVPREPLOG         NVARCHAR(50) = ''
         , @c_WSVPREPLOG_Option5 NVARCHAR(MAX)= ''
         
         , @c_ReplenishmentGroup NVARCHAR(10) = ''
         
         , @c_VioceConfirmStatus NVARCHAR(10) = ''
         
         , @c_SQL                NVARCHAR(4000)= ''
         , @c_SQLParms           NVARCHAR(1000)= ''               
   
   IF OBJECT_ID('tempdb..#TMP_Replenishment','u') IS NOT NULL  
   BEGIN 
      DROP TABLE #TMP_Replenishment;   
   END 
         
   CREATE TABLE #TMP_Replenishment   
         ( ReplenishmentKey   NVARCHAR(10)   NOT NULL DEFAULT('') PRIMARY KEY
         , ReplenishmentGroup NVARCHAR(10)   NOT NULL DEFAULT('') 
         , Confirmed          NVARCHAR(10)   NOT NULL DEFAULT('N') 
         )

   SET @b_Success = 1
   SET @c_ErrMsg = ''
   
   SELECT @c_WSVPREPLOG = fgr.Authority, @c_WSVPREPLOG_Option5 = fgr.Option5 FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', @c_TableName) AS fgr
   
   IF @c_WSVPREPLOG NOT IN ( '1' )
   BEGIN
      GOTO QUIT_SP
   END
   
   SET @c_VioceConfirmStatus = 'Y'
   SELECT @c_VioceConfirmStatus = dbo.fnc_GetParamValueFromString('@c_VoiceConfirmStatus', @c_WSVPREPLOG_Option5, @c_VioceConfirmStatus) 
   
   SET @c_SQL = N'SELECT r.ReplenishmentKey, r.ReplenishmentGroup, r.Confirmed'
              + ' FROM dbo.REPLENISHMENT AS r WITH (NOLOCK)'
              + ' JOIN dbo.LOC AS l WITH (NOLOCK) ON r.FromLoc = l.loc'
              + ' WHERE r.Storerkey = @c_Storerkey'
              + ' AND   l.Facility = @c_Facility' 
              + CASE WHEN @c_ReplGroup = 'ALL' THEN '' 
                     ELSE ' AND r.ReplenishmentGroup = @c_ReplGroup'
                     END 
              + CASE WHEN @c_Zone02 IN ( 'ALL', '' ) THEN '' 
                     ELSE ' AND l.PutawayZone IN ( @c_Zone02, @c_Zone03, @c_Zone04
                          , @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09
                          , @c_Zone10, @c_Zone11, @c_Zone12)' 
                     END  
    
   SET @c_SQLParms = N'@c_Storerkey    NVARCHAR(15)'
                   + ',@c_Facility     NVARCHAR(5)'
                   + ',@c_ReplGroup    NVARCHAR(10)' 
                   + ',@c_Zone02       NVARCHAR(10)'                                       
                   + ',@c_Zone03       NVARCHAR(10)'   
                   + ',@c_Zone04       NVARCHAR(10)'                         
                   + ',@c_Zone05       NVARCHAR(10)'                                       
                   + ',@c_Zone06       NVARCHAR(10)'   
                   + ',@c_Zone07       NVARCHAR(10)'   
                   + ',@c_Zone08       NVARCHAR(10)'   
                   + ',@c_Zone09       NVARCHAR(10)'                         
                   + ',@c_Zone10       NVARCHAR(500)'                                       
                   + ',@c_Zone11       NVARCHAR(500)'   
                   + ',@c_Zone12       NVARCHAR(10)'                       
   
   INSERT INTO #TMP_Replenishment
       (
           ReplenishmentKey,
           ReplenishmentGroup,
           Confirmed
       )
   EXEC sp_ExecuteSQL  @c_SQL
                     , @c_SQLParms
                     , @c_Storerkey 
                     , @c_Facility  
                     , @c_ReplGroup 
                     , @c_Zone02                                         
                     , @c_Zone03     
                     , @c_Zone04                           
                     , @c_Zone05                                         
                     , @c_Zone06     
                     , @c_Zone07     
                     , @c_Zone08     
                     , @c_Zone09                           
                     , @c_Zone10                                          
                     , @c_Zone11      
                     , @c_Zone12 
                                                              
   IF NOT EXISTS (SELECT 1 FROM #TMP_Replenishment AS r 
                  WHERE r.Confirmed NOT IN ( @c_VioceConfirmStatus, 'Y')
                  )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 86010
      SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Replenishment are confirmed. (isp_RCM_REPL_Dyson_VoicePick)'
      GOTO QUIT_SP
   END
   
   IF EXISTS ( SELECT 1 FROM #TMP_Replenishment AS r 
               WHERE r.Confirmed NOT IN ( @c_VioceConfirmStatus, 'Y')
               AND r.ReplenishmentGroup = ''
             )
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 86020
      SET @c_Errmsg = 'NSQL' + CONVERT(CHAR(5), @n_Err) + ': Blank ReplenishmentGroup found . (isp_RCM_REPL_Dyson_VoicePick)'
      GOTO QUIT_SP
   END

   SET @c_ReplenishmentGroup = ''
   WHILE 1 = 1 AND @n_Continue = 1
   BEGIN
      SELECT TOP 1 @c_ReplenishmentGroup = r.ReplenishmentGroup
      FROM #TMP_Replenishment AS r 
      WHERE r.Confirmed NOT IN ( @c_VioceConfirmStatus, 'Y' )
      AND r.ReplenishmentGroup <> ''
      AND r.ReplenishmentGroup > @c_ReplenishmentGroup
      GROUP BY r.ReplenishmentGroup
      ORDER BY r.ReplenishmentGroup
      
      IF @@ROWCOUNT = 0 
      BEGIN
         BREAK
      END
       
      SET @b_success = 1
      EXEC ispGenTransmitLog2 @c_Tablename
                           ,  @c_ReplenishmentGroup
                           ,  ''
                           ,  @c_StorerKey
                           ,  ''    
                           ,  @b_success OUTPUT    
                           ,  @n_Err OUTPUT    
                           ,  @c_ErrMsg OUTPUT    
                         
      IF @b_success <> 1    
      BEGIN    
         SET @n_continue = 3    
         SET @n_Err = 86020    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err)    
                       + ': ispGenTransmitLog2 Failed. (isp_RCM_REPL_Dyson_VoicePick)'  
      END
      
      IF @n_Continue = 1
      BEGIN
         ;WITH upd AS 
         (  SELECT r.ReplenishmentKey
            FROM #TMP_Replenishment r
            WHERE r.Confirmed <> @c_VioceConfirmStatus
            AND r.ReplenishmentGroup <> ''
            AND r.ReplenishmentGroup = @c_ReplenishmentGroup
         )
         UPDATE r
            SET r.Confirmed = @c_VioceConfirmStatus
               ,r.EditWho = SUSER_SNAME()
               ,r.EditDate= GETDATE()
         FROM dbo.REPLENISHMENT r
         JOIN upd ON upd.ReplenishmentKey = r.ReplenishmentKey
         
         IF @@ERROR <> 0    
         BEGIN    
            SET @n_continue = 3    
            SET @n_Err = 86030    
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),@n_Err)   
                          + ': Update Replenishment table Failed. (isp_RCM_REPL_Dyson_VoicePick)' 
         END
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

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'isp_RCM_REPL_Dyson_VoicePick'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END  

GO