SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/*************************************************************************/  
/* Stored Procedure: lsp_Start_Replenishment_Wrapper                     */  
/* Creation Date: 28-FEB-2018                                            */  
/* Copyright: Maersk                                                     */  
/* Written by:                                                           */  
/*                                                                       */  
/* Purpose:                                                              */  
/*                                                                       */  
/* Called By:                                                            */  
/*                                                                       */  
/*                                                                       */  
/* Version: 1.4                                                          */  
/*                                                                       */  
/* Data Modifications:                                                   */  
/*                                                                       */  
/* Updates:                                                              */  
/* Date        Author   Ver   Purposes                                   */ 
/* 2021-02-09  mingle01 1.1   Add Big Outer Begin try/Catch              */
/*                            Execute Login if @c_UserName<>SUSER_SNAME()*/
/* 2021-03-31  Wan01    1.2   LFWM-2693 - UAT  Philippines  SCE  Zone 10 */
/*                            Only First Sort Gets Generated; Zone 11 no */
/*                            result                                     */
/* 2022-08-11  Wan02    1.3   LFWM-3641 - [CN] DYSON Voice Picking       */
/*                            replenishment trigger button New           */
/* 2022-08-11  Wan02    1.3   DevOps Combine Script                      */
/* 2024-04-23  Wan03    1.4   UWP-17448 Fixed infity commit tran loop    */
/*************************************************************************/   
CREATE   PROCEDURE [WM].[lsp_Start_Replenishment_Wrapper]  
   @c_Storerkey            NVARCHAR(15) = ''
,  @c_Facility             NVARCHAR(10) = ''
,  @c_ReplenishStrategyKey NVARCHAR(30) = ''      
,  @c_ReplGroup            NVARCHAR(10) = 'ALL'
,  @c_Zone02               NVARCHAR(10) = ''
,  @c_Zone03               NVARCHAR(10) = ''
,  @c_Zone04               NVARCHAR(10) = ''
,  @c_Zone05               NVARCHAR(10) = ''
,  @c_Zone06               NVARCHAR(10) = ''
,  @c_Zone07               NVARCHAR(10) = ''
,  @c_Zone08               NVARCHAR(10) = ''
,  @c_Zone09               NVARCHAR(10) = ''
,  @c_Zone10               NVARCHAR(500)= ''         --Wan01 Increase Length
,  @c_Zone11               NVARCHAR(500)= ''         --Wan01 Increase Length
,  @c_Zone12               NVARCHAR(10) = ''
,  @n_WarningNo            INT          = 0  OUTPUT
,  @c_ProceedWithWarning   CHAR(1)      = 'N' 
,  @c_UserName             NVARCHAR(128)= ''
,  @b_Success              INT          = 1  OUTPUT   
,  @n_Err                  INT          = 0  OUTPUT
,  @c_Errmsg               NVARCHAR(255)= '' OUTPUT
AS  
BEGIN  
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_Continue                 INT = 1
         , @n_StartTCnt                INT = @@TRANCOUNT 
                 
         , @n_Count                    INT = 0 
         , @n_RowRef                   INT = 0

         , @c_ReplenType               NVARCHAR(10)   = ''
         , @c_ReplenSPName             NVARCHAR(500)  = ''
         , @c_ReplenSQL                NVARCHAR(4000) = ''
         , @c_ReplenSQL_Origin         NVARCHAR(500) = ''

         , @n_ParmPosStart             INT = 0
         , @n_ParmPosEnd               INT = 0
         , @c_ParmName                 NVARCHAR(50)   = ''

         , @b_Log                      BIT = 0 
         , @c_Status                   NVARCHAR(10)   = '9'
         
         , @c_PreGenReplVLDN           NVARCHAR(50) = ''                                           --Wan02
         , @c_PreGenReplVLDN_Option5   NVARCHAR(MAX)= ''                                           --Wan02
         , @c_ReplDataVLDNCond         NVARCHAR(2000)= ''                                          --Wan02
         , @c_SQL                      NVARCHAR(4000)= ''                                          --Wan02
         , @c_SQLParms                 NVARCHAR(4000)= ''                                          --Wan02

   SET @b_Success = 1
   SET @c_ErrMsg = ''

   SET @n_Err = 0 
   --(mingle01) - START   
   IF SUSER_SNAME() <> @c_UserName
   BEGIN
      EXEC [WM].[lsp_SetUser] 
            @c_UserName = @c_UserName  OUTPUT
         ,  @n_Err      = @n_Err       OUTPUT
         ,  @c_ErrMsg   = @c_ErrMsg    OUTPUT
                
      IF @n_Err <> 0 
      BEGIN
         GOTO EXIT_SP
      END
    
      EXECUTE AS LOGIN = @c_UserName
   END
   --(mingle01) - END
   
   --(mingle01) - START
   BEGIN TRY

      IF @c_ProceedWithWarning = 'N'
      BEGIN

         IF ISNULL(RTRIM(@c_Storerkey),'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 551601
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Storerkey cannot be blank. (lsp_Start_Replenishment_Wrapper)'
            GOTO EXIT_SP
         END

         IF ISNULL(RTRIM(@c_Facility),'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 551602
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Facility cannot be blank. (lsp_Start_Replenishment_Wrapper)'
            GOTO EXIT_SP
         END

         IF ISNULL(RTRIM(@c_ReplenishStrategyKey),'') = ''
         BEGIN
            SET @n_Continue = 3
            SET @n_err = 551603
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) + ': Replenishment Strategy Key is required. (lsp_Start_Replenishment_Wrapper)'
            GOTO EXIT_SP
         END

         SELECT @n_RowRef = PRM.RowRef
         FROM REPLENISHMENTPARMS PRM WITH (NOLOCK)
         WHERE PRM.Storerkey= @c_Storerkey
         AND   PRM.Facility = @c_Facility 

         IF @n_RowRef > 0
         BEGIN
            BEGIN TRY
               UPDATE REPLENISHMENTPARMS
               SET  Storerkey             = @c_Storerkey            
                  , Facility              = @c_Facility
                  , ReplenishStrategyKey  = @c_ReplenishStrategyKey 
                  , ReplenishmentGroup    = @c_ReplGroup
                  , Zone02                = @c_Zone02 
                  , Zone03                = @c_Zone03 
                  , Zone04                = @c_Zone04 
                  , Zone05                = @c_Zone05 
                  , Zone06                = @c_Zone06
                  , Zone07                = @c_Zone07 
                  , Zone08                = @c_Zone08
                  , Zone09                = @c_Zone09
                  , Zone10                = @c_Zone10 
                  , Zone11                = @c_Zone11 
                  , Zone12                = @c_Zone12 
                  , EditWho               = SUSER_SNAME()
                  , EditDate              = GETDATE()
                  , Trafficcop            = NULL
               WHERE RowRef = @n_RowRef 
            END TRY
            BEGIN CATCH
               SET @n_continue = 3
               SET @n_err = 551604
               SET @c_ErrMsg = ERROR_MESSAGE()    
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                              + ': Update REPLENISHMENTPARMS Fail. (lsp_Start_Replenishment_Wrapper)'
                              + ' (' + @c_ErrMsg + ')'
               GOTO EXIT_SP
            END CATCH
         END
         ELSE
         BEGIN
            -- INSERT INTO REPLENISHPARMS
            BEGIN TRY
               INSERT INTO REPLENISHMENTPARMS
                  (  Storerkey, Facility, ReplenishStrategyKey, ReplenishmentGroup
                  ,  Zone02, Zone03, Zone04, Zone05, Zone06, Zone07, Zone08, Zone09
                  ,  Zone10, Zone11, Zone12
                  )
               VALUES
                  (  @c_Storerkey, @c_Facility, @c_ReplenishStrategyKey, @c_ReplGroup
                  ,  @c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09
                  ,  @c_Zone10, @c_Zone11, @c_Zone12
                  )
            END TRY
            BEGIN CATCH
               SET @n_continue = 3
               SET @n_err = 551605
               SET @c_ErrMsg = ERROR_MESSAGE()    
               SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                              + ': Insert REPLENISHMENTPARMS Fail. (lsp_Start_Replenishment_Wrapper)'
                              + ' (' + @c_ErrMsg + ')'
               GOTO EXIT_SP
            END CATCH
         END
         
         --(Wan02) - START
         ----------------------------------
         -- Pre Generate Validation - START
         ----------------------------------
         SELECT @c_PreGenReplVLDN = fgr.Authority, @c_PreGenReplVLDN_Option5 = fgr.Option5 FROM dbo.fnc_GetRight2(@c_Facility, @c_Storerkey, '', 'PreGenReplVLDN') AS fgr
   
         IF @c_PreGenReplVLDN IN ( '1' )
         BEGIN
            -- @c_InvDataVLDNCond, @c_PreGenRepl_SP - For future enhancement 
            SET @c_ReplDataVLDNCond = ''
            SELECT @c_ReplDataVLDNCond = dbo.fnc_GetParamValueFromString('@c_ReplDataVLDNCond', @c_PreGenReplVLDN_Option5, @c_ReplDataVLDNCond) 
            
            IF @c_ReplDataVLDNCond <> ''
            BEGIN
               IF CHARINDEX('AND', LEFT(@c_ReplDataVLDNCond,10),1) = 0
               BEGIN
                  SET @c_ReplDataVLDNCond = 'AND ' + @c_ReplDataVLDNCond
               END
               SET @b_Success = 1
               SET @c_SQL = N'SELECT TOP 1 @b_Success = 0'
                          + ' FROM dbo.REPLENISHMENT WITH (NOLOCK)'
                          + ' JOIN dbo.LOC WITH (NOLOCK) ON REPLENISHMENT.FromLoc = LOC.loc'
                          + ' WHERE REPLENISHMENT.Storerkey = @c_Storerkey'
                          + ' AND   LOC.Facility = @c_Facility' 
                          + CASE WHEN @c_ReplGroup = 'ALL' THEN '' 
                                 ELSE ' AND REPLENISHMENT.ReplenishmentGroup = @c_ReplGroup'
                                 END 
                          + CASE WHEN @c_Zone02 IN ( 'ALL', '' ) THEN '' 
                                 ELSE ' AND LOC.PutawayZone IN ( @c_Zone02, @c_Zone03, @c_Zone04
                                       , @c_Zone05, @c_Zone06, @c_Zone07, @c_Zone08, @c_Zone09
                                       , @c_Zone10, @c_Zone11, @c_Zone12)' 
                                 END 
                          + ' ' + @c_ReplDataVLDNCond
    
               SET @c_SQLParms = N'@b_Success      INT   OUTPUT'
                               + ',@c_Storerkey    NVARCHAR(15)'
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
                               
               EXEC sp_ExecuteSQL  @c_SQL
                                 , @c_SQLParms
                                 , @b_Success   OUTPUT
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
               IF @b_Success = 0
               BEGIN
                  SET @n_Continue = 3
                  SET @n_Err = 551611
                  SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_Err) 
                                + ': Fail By Replenishment Data Validation condition setup in Storerconfig: PreGenReplVLDN.'
                                + ' (lsp_Start_Replenishment_Wrapper)'
                  GOTO EXIT_SP
               END
            END
         END
         ----------------------------------
         -- Pre Generate Validation - END
         ----------------------------------       
      END
       
      IF @n_WarningNo < 1
      BEGIN
         SET @n_WarningNo = 1
         IF ISNULL(RTRIM(@c_Zone02),'') = 'ALL'  
         BEGIN
            SET @n_Count = 0 
               
            SELECT @n_Count = Count(LOC.LOC) 
            FROM   Replenishment R WITH (NOLOCK) 
            JOIN   LOC (NOLOCK) ON R.TOLOC = LOC.LOC 
            LEFT OUTER JOIN STORERCONFIG SCF WITH (NOLOCK) ON (SCF.StorerKey = R.StorerKey 
                                                            AND SCF.ConfigKey = 'RDTDYNAMICPICK' 
                                                            AND SCF.sValue = '1')
            WHERE ((R.CONFIRMED IN ('N','L') AND SCF.sVAlue = '1') OR (SCF.sVAlue IS NULL))
            AND LOC.Facility = @c_Facility
            AND (R.ReplenishmentGroup = @c_ReplGroup OR @c_ReplGroup = 'ALL')      
            AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')
         END
         ELSE
         BEGIN
            SET @n_Count = 0 
               
            SELECT @n_Count = Count(LOC.LOC) 
            FROM   Replenishment R WITH (NOLOCK) 
            JOIN   LOC (NOLOCK) ON R.TOLOC = LOC.LOC 
            LEFT OUTER JOIN STORERCONFIG SCF WITH (NOLOCK) ON (SCF.StorerKey = R.StorerKey 
                                                            AND SCF.ConfigKey = 'RDTDYNAMICPICK' 
                                                            AND SCF.sValue = '1')
            WHERE ((R.CONFIRMED IN ('N','L') AND SCF.sVAlue = '1') OR (SCF.sVAlue IS NULL))
            AND LOC.Facility = @c_Facility
            AND LOC.PutawayZone IN (@c_Zone02, @c_Zone03, @c_Zone04, @c_Zone05, 
                                    @c_Zone06, @c_Zone07,  @c_Zone08,  @c_Zone09,  
                                    @c_Zone10,  @c_Zone11,  @c_Zone12)              
            AND (R.ReplenishmentGroup = @c_ReplGroup OR @c_ReplGroup = 'ALL')      
            AND (R.Storerkey = @c_Storerkey OR @c_Storerkey = 'ALL')          
         END

         IF @n_Count > 0 
         BEGIN
            SET @c_ErrMsg = 'Previous Generated Replenishment is not confirmed yet. Regenarate ?'
            GOTO EXIT_SP 
         END
      END

      IF @n_WarningNo < 2
      BEGIN
         SET @n_WarningNo = 2
         SET @c_ErrMsg = 'Generate Replenishment Transaction?'
         GOTO EXIT_SP     
      END  

      BEGIN TRY
         EXEC isp_DeleteNotConfirmRepl
               @c_facility  = @c_Facility   
            ,  @c_zone02    = @c_Zone02     
            ,  @c_zone03    = @c_Zone03     
            ,  @c_zone04    = @c_Zone04     
            ,  @c_zone05    = @c_Zone05     
            ,  @c_zone06    = @c_Zone06     
            ,  @c_zone07    = @c_Zone07     
            ,  @c_zone08    = @c_Zone08     
            ,  @c_zone09    = @c_Zone09     
            ,  @c_zone10    = @c_Zone10     
            ,  @c_zone11    = @c_Zone11     
            ,  @c_zone12    = @c_Zone12     
            ,  @c_storerkey = @c_Storerkey  
            ,  @c_ReplGroup = @c_ReplGroup  
            ,  @b_Success   = @b_Success OUTPUT
            ,  @n_Err       = @n_Err     OUTPUT
            ,  @c_ErrMsg    = @c_Errmsg  OUTPUT
      END TRY
      BEGIN CATCH
         SET @n_err = 551606
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing isp_DeleteNotConfirmRepl. (lsp_Start_Replenishment_Wrapper)'
                        + '( ' + @c_errmsg + ' )'
      END CATCH      

      IF @b_Success = 0 OR @n_Err <> 0 
      BEGIN
         SET @n_Continue = 3
         GOTO EXIT_SP 
      END   

      SET @c_ReplenType = ''
      SET @c_ReplenSQL  = ''
      SELECT TOP 1 
             @c_ReplenType  = RTRIM(RS.[Type])
         ,   @c_ReplenSQL   = RTRIM(RSD.ReplenCode)
      FROM dbo.REPLENISHSTRATEGY       RS WITH (NOLOCK)
      JOIN dbo.REPLENISHSTRATEGYDETAIL RSD WITH (NOLOCK) ON (RS.ReplenishStrategyKey = RSD.ReplenishStrategyKey)
      WHERE RS.ReplenishStrategyKey = @c_ReplenishStrategyKey
      AND RTRIM(RSD.ReplenCode) <> ''

      IF @c_ReplenType = '' AND @c_ReplenSQL = ''
      BEGIN
         GOTO EXIT_SP 
      END

      IF @c_ReplenType = 'RULES'
      BEGIN
         SET @c_ReplenSQL = 'isp_GenReplenishment_STD '
                          + '''' + ISNULL(RTRIM(@c_Facility),'') + ''''
                          + ','''+ ISNULL(RTRIM(@c_Storerkey),'')+ ''''
                          + ','''+ ISNULL(RTRIM(@c_ReplenishStrategyKey),'') + ''''
                          + ','''+ ISNULL(RTRIM(@c_ReplGroup),'')+ ''''
                          + ','''+ ISNULL(RTRIM(@c_Zone02),'')   + ''''
                          + ','''+ ISNULL(RTRIM(@c_Zone03),'')   + ''''
                          + ','''+ ISNULL(RTRIM(@c_Zone04),'')   + ''''
                          + ','''+ ISNULL(RTRIM(@c_Zone05),'')   + ''''
                          + ','''+ ISNULL(RTRIM(@c_Zone06),'')   + '''' 
                          + ','''+ ISNULL(RTRIM(@c_Zone07),'')   + ''''
                          + ','''+ ISNULL(RTRIM(@c_Zone08),'')   + '''' 
                          + ','''+ ISNULL(RTRIM(@c_Zone09),'')   + ''''
                          + ','''+ ISNULL(RTRIM(@c_Zone10),'')   + '''' 
                          + ','''+ ISNULL(RTRIM(@c_Zone11),'')   + '''' 
                          + ','''+ ISNULL(RTRIM(@c_Zone12),'')   + '''' 
                     
      END

      IF @c_ReplenType = 'STOREDPROC' AND @c_ReplenSQL = ''
      BEGIN
         SET @n_Continue = 3 
         SET @n_err = 551607
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Replenish Code not setup for STOREDPROC Replenishment Type. (lsp_Start_Replenishment_Wrapper)'
         GOTO EXIT_SP   
      END

      SET @c_ReplenSPName = RTRIM(SUBSTRING(@c_ReplenSQL, 1, CHARINDEX('@',@c_ReplenSQL,1) - 1))

      IF NOT EXISTS (SELECT 1 
                     FROM dbo.sysobjects 
                     WHERE name = RTRIM(@c_ReplenSPName)
                     AND type = 'P'
                     )
      BEGIN
         SET @n_Continue = 3 
         SET @n_err = 551608
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Replenishment SP: ' + RTRIM(@c_ReplenSPName) + ' not found. (lsp_Start_Replenishment_Wrapper)'
                       + ' |' + RTRIM(@c_ReplenSPName)
         GOTO EXIT_SP   
      END

      SET @c_ReplenSQL_Origin = @c_ReplenSQL
      SET @n_ParmPosStart = CHARINDEX('@',@c_ReplenSQL_Origin,1) 

      WHILE @n_ParmPosStart > 0  
      BEGIN
         SET @n_ParmPosEnd = CHARINDEX(',', @c_ReplenSQL_Origin, @n_ParmPosStart)

         IF @n_ParmPosEnd <= 0
         BEGIN
            SET @n_ParmPosEnd = LEN(@c_ReplenSQL_Origin) + 1
         END

         IF @n_ParmPosEnd >  0
         BEGIN 
            SET @c_ParmName = RTRIM(LTRIM(SUBSTRING(@c_ReplenSQL_Origin, @n_ParmPosStart, @n_ParmPosEnd - @n_ParmPosStart )))

            IF @c_ParmName = '@c_Storerkey'  SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Storerkey),'') + '''' )
            IF @c_ParmName = '@c_Facility'   SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Facility),'')  + '''' )
            IF @c_ParmName = '@c_ReplGroup'  SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_ReplGroup),'') + '''' )
            IF @c_ParmName = '@c_Zone02'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone02),'') + '''' )
            IF @c_ParmName = '@c_Zone03'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone03),'') + '''' )
            IF @c_ParmName = '@c_Zone04'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone04),'') + '''' )
            IF @c_ParmName = '@c_Zone05'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone05),'') + '''' )
            IF @c_ParmName = '@c_Zone06'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone06),'') + '''' )
            IF @c_ParmName = '@c_Zone07'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone07),'') + '''' )
            IF @c_ParmName = '@c_Zone08'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone08),'') + '''' )
            IF @c_ParmName = '@c_Zone09'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone09),'') + '''' )
            IF @c_ParmName = '@c_Zone10'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone10),'') + '''' )
            IF @c_ParmName = '@c_Zone11'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone11),'') + '''' )
            IF @c_ParmName = '@c_Zone12'     SET @c_ReplenSQL = REPLACE(@c_ReplenSQL, @c_ParmName, '''' + ISNULL(RTRIM(@c_Zone12),'') + '''' )

            SET @n_ParmPosStart = 0 

            IF @n_ParmPosEnd <= LEN(@c_ReplenSQL_Origin)
            BEGIN
               SET @n_ParmPosStart = @n_ParmPosEnd + 1 
            END
         END
      END

      BEGIN TRY 
         SET @b_Log = 1                 
         EXEC ( @c_ReplenSQL )
      END TRY

      BEGIN CATCH
         SET @n_Continue = 3   
         SET @n_err = 551609
         SET @c_ErrMsg = ERROR_MESSAGE()
         SET @c_errmsg = 'NSQL' +CONVERT(CHAR(6),@n_err) + ': Error Executing Replenish Code: ' + RTRIM(@c_ReplenSPName) + '. (lsp_Start_Replenishment_Wrapper)'
                       + '( ' + @c_errmsg + ' ) |' + RTRIM(@c_ReplenSPName)         --(wan03)       
         GOTO EXIT_SP    
      END CATCH
   END TRY
   
   BEGIN CATCH
      SET @n_Continue = 3
      SET @c_ErrMsg = ERROR_MESSAGE()
      GOTO EXIT_SP
   END CATCH
   --(mingle01) - END
   EXIT_SP:
   IF (XACT_STATE()) = -1                                                           --(Wan03) - START  
   BEGIN
      SET @n_continue = 3
      ROLLBACK TRAN
   END                                                                              --(Wan03) - END

   IF @n_Continue = 3   
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

      SET @c_ErrMsg = ISNULL(@c_ErrMsg,'')

      EXECUTE nsp_logerror @n_err, @c_ErrMsg, 'lsp_Start_Replenishment_Wrapper'
      SET @n_WarningNo = 0

      SET @c_Status = '5'
   END
   ELSE
   BEGIN
      SET @b_Success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END

   IF @b_Log = 1
   BEGIN
      WHILE @@TRANCOUNT > 0
      BEGIN 
         COMMIT TRAN
      END 

      BEGIN TRY
         INSERT INTO GENREPLENISHMENTLOG
            (  Storerkey, Facility, ReplenishStrategyKey, GenParmString
            ,  [Status]
            )
         VALUES
            (  @c_Storerkey, @c_Facility, @c_ReplenishStrategyKey, @c_ReplenSQL
            ,  @c_Status
            )
      END TRY
      BEGIN CATCH
         SET @n_continue = 3
         SET @n_err = 551610
         SET @c_ErrMsg = ERROR_MESSAGE()    
         SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(6), @n_err) 
                        + ': Insert GENREPLENISHMENTLOG Fail. (lsp_Start_Replenishment_Wrapper)'
                        + ' (' + @c_ErrMsg + ')'
      END CATCH
   END      

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN 
      BEGIN TRAN
   END
   REVERT
END  

GO