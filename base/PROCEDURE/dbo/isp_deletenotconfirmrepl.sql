SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure isp_DeleteNotConfirmRepl                               */
/* Creation Date 20-DEC-2013                                               */
/* Copyright IDS                                                           */
/* Written by YTWan                                                        */
/*                                                                         */
/* Purpose Move Delete Not Confirm Replenishment Logic from PB to SP       */
/*         w_replenishment_Jdh.of_delnotconfirmrepl                        */
/*                                                                         */
/* Called By                                                               */
/*                                                                         */
/*                                                                         */
/* PVCS Version 1.2                                                        */
/*                                                                         */
/* Version 5.4                                                             */
/*                                                                         */
/* Data Modifications                                                      */
/*                                                                         */
/* Updates                                                                 */
/* Date         Author  Ver   Purposes                                     */
/* 04-JAN-2017  Wan01   1.1   Locking                                      */
/* 27-AUG-2019  Wan02   1.2   WMS-10379 - PH Unilever Regular Replenishment*/
/***************************************************************************/  
CREATE PROC [dbo].[isp_DeleteNotConfirmRepl]  
(     @c_facility         NVARCHAR(10)
,     @c_zone02           NVARCHAR(10)
,     @c_zone03           NVARCHAR(10)
,     @c_zone04           NVARCHAR(10)
,     @c_zone05           NVARCHAR(10)
,     @c_zone06           NVARCHAR(10)
,     @c_zone07           NVARCHAR(10)
,     @c_zone08           NVARCHAR(10)
,     @c_zone09           NVARCHAR(10)
,     @c_zone10           NVARCHAR(10)
,     @c_zone11           NVARCHAR(10)
,     @c_zone12           NVARCHAR(10)
,     @c_storerkey        NVARCHAR(15) 
,     @c_ReplGroup        NVARCHAR(10) = 'ALL'
,     @b_Success          INT             OUTPUT
,     @n_Err              INT             OUTPUT
,     @c_ErrMsg           NVARCHAR(255)   OUTPUT
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTCount        INT 
                                 
         , @c_rdtDynamicpick     NVARCHAR(10)
         , @c_RepleDelLog        NVARCHAR(10)

         , @c_ReplSQL            NVARCHAR(MAX)  --(Wan01)
         , @c_ReplDelSQL         NVARCHAR(MAX)  --(Wan01)

         , @n_RowRef             BIGINT         --(Wan01)
         , @c_ReplenishmentKey   NVARCHAR(10)   --(Wan01) 
         
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCount = @@TRANCOUNT  
  
   EXEC nspGetRight  
         @c_Facility  = NULL 
       , @c_StorerKey = @c_StorerKey 
       , @c_sku       = NULL
       , @c_ConfigKey = 'RDTDYNAMICPICK'  
       , @b_Success   = @b_Success                  OUTPUT  
       , @c_authority = @c_rdtDynamicpick           OUTPUT   
       , @n_err       = @n_err                      OUTPUT   
       , @c_errmsg    = @c_errmsg                   OUTPUT  

   EXEC nspGetRight  
         @c_Facility  = NULL 
       , @c_StorerKey = NULL 
       , @c_sku       = NULL
       , @c_ConfigKey = 'RepleDelLog'  
       , @b_Success   = @b_Success                  OUTPUT  
       , @c_authority = @c_RepleDelLog              OUTPUT   
       , @n_err       = @n_err                      OUTPUT   
       , @c_errmsg    = @c_errmsg                   OUTPUT 
        

   --(Wan01) - START
   SET @c_Facility  = ISNULL(RTRIM(@c_Facility),'')
   SET @c_storerkey = ISNULL(RTRIM(@c_storerkey),'')
   SET @c_ReplGroup = ISNULL(RTRIM(@c_ReplGroup),'')
   SET @c_zone02 = ISNULL(RTRIM(@c_Zone02),'')
   SET @c_zone03 = ISNULL(RTRIM(@c_Zone03),'')
   SET @c_zone04 = ISNULL(RTRIM(@c_Zone04),'')
   SET @c_zone05 = ISNULL(RTRIM(@c_Zone05),'')
   SET @c_zone06 = ISNULL(RTRIM(@c_Zone06),'')
   SET @c_zone07 = ISNULL(RTRIM(@c_Zone07),'')
   SET @c_zone08 = ISNULL(RTRIM(@c_Zone08),'')
   SET @c_zone09 = ISNULL(RTRIM(@c_Zone09),'')
   SET @c_zone10 = ISNULL(RTRIM(@c_Zone10),'')
   SET @c_zone11 = ISNULL(RTRIM(@c_Zone11),'')
   SET @c_zone12 = ISNULL(RTRIM(@c_Zone12),'')

   SET @c_ReplSQL = ''
   SET @c_ReplDelSQL = ''
   
   IF IsNULL(@c_Facility,'')  <> ''  
   BEGIN
      IF @c_Zone02 = 'ALL' 
      BEGIN
         IF @c_storerkey = 'ALL' 
         BEGIN
            SET @c_ReplSQL = N'DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR'
                           + ' SELECT REPLENISHMENT.ReplenishmentKey'
                           + ' FROM REPLENISHMENT WITH (NOLOCK) '
                           + ' JOIN LOC (NOLOCK) ON (REPLENISHMENT.TOLOC = LOC.LOC)' 
                           + ' LEFT OUTER JOIN STORERCONFIG WITH (NOLOCK)'
                           +                 ' ON (STORERCONFIG.StorerKey = REPLENISHMENT.StorerKey' 
                           +                 ' AND STORERCONFIG.ConfigKey = ''RDTDYNAMICPICK'' AND STORERCONFIG.sValue = ''1'')'
                           + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'                 --(Wan02)  
                           + ' WHERE LOC.Facility = N''' + @c_Facility + ''''
                           + ' AND (REPLENISHMENT.ReplenishmentGroup <> ''DYNAMIC'')'  
                           + ' AND ((REPLENISHMENT.Confirmed = ''N'' AND STORERCONFIG.sVAlue = ''1'') OR (STORERCONFIG.sVAlue IS NULL))'
                           + ' AND (REPLENISHMENT.ReplenishmentGroup = N''' + @c_ReplGroup + ''' OR N''' + @c_ReplGroup + ''' = ''ALL'')'
                           + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                            --(Wan02)                
                           + '      (SCFG1.Authority = ''1'' AND ISNULL(REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(REPLENISHMENT.Wavekey,'''') ='''') )' --(Wan02)

            SET @c_ReplDelSQL = N'DECLARE CUR_DELREPL CURSOR FAST_FORWARD READ_ONLY FOR' 
                           + ' SELECT DEL_REPLENISHMENT.RowRef'
                           + ' FROM DEL_REPLENISHMENT WITH (NOLOCK)'           
                           + ' JOIN  LOC (NOLOCK) ON (DEL_REPLENISHMENT.TOLOC = LOC.LOC)' 
                           + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, DEL_REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'             --(Wan02)  
                           + ' WHERE LOC.Facility = N''' + @c_Facility + ''''
                           + ' AND  DEL_REPLENISHMENT.DeleteDate < DATEADD(Mi, -10, GETDATE() )' 
                           + ' AND (DEL_REPLENISHMENT.ReplenishmentGroup = ''' + @c_ReplGroup + ''' OR  N''' + @c_ReplGroup + ''' = ''ALL'')'
                           + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                                     --(Wan02)
                           + '      (SCFG1.Authority = ''1'' AND ISNULL(DEL_REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(DEL_REPLENISHMENT.Wavekey,'''') ='''') )'  --(Wan02)
         END 
         ELSE
         BEGIN
            SET @c_ReplSQL = N'DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR'
                           + ' SELECT REPLENISHMENT.ReplenishmentKey'
                           + ' FROM REPLENISHMENT WITH (NOLOCK) '
                           + ' JOIN LOC (NOLOCK) ON (REPLENISHMENT.TOLOC = LOC.LOC)' 
                           + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'                 --(Wan02) 
                           + ' WHERE LOC.Facility = N''' + @c_Facility + ''''
                           + ' AND REPLENISHMENT.ReplenishmentGroup <> ''DYNAMIC''' 
                           + ' AND REPLENISHMENT.Storerkey = N''' + @c_Storerkey + ''''                            
                           + ' AND (REPLENISHMENT.Confirmed = ''N'' OR N''' + @c_rdtDynamicpick +''' <> ''1'')'
                           + ' AND (REPLENISHMENT.ReplenishmentGroup = N''' + @c_ReplGroup + ''' OR N''' + @c_ReplGroup + ''' = ''ALL'')'
                           + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                            --(Wan02)
                           + '      (SCFG1.Authority = ''1'' AND ISNULL(REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(REPLENISHMENT.Wavekey,'''') ='''') )' --(Wan02)

            SET @c_ReplDelSQL = N'DECLARE CUR_DELREPL CURSOR FAST_FORWARD READ_ONLY FOR' 
                           + ' SELECT DEL_REPLENISHMENT.RowRef'
                           + ' FROM DEL_REPLENISHMENT WITH (NOLOCK)'           
                           + ' JOIN LOC (NOLOCK) ON (DEL_REPLENISHMENT.TOLOC = LOC.LOC)'
                           + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, DEL_REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'             --(Wan02)  
                           + ' WHERE LOC.Facility = N''' + @c_Facility + ''''
                           + ' AND  DEL_REPLENISHMENT.Storerkey = N''' + @c_Storerkey + ''''                             
                           + ' AND  DEL_REPLENISHMENT.DeleteDate < DATEADD(Mi, -10, GETDATE() )' 
                           + ' AND (DEL_REPLENISHMENT.ReplenishmentGroup = ''' + @c_ReplGroup + ''' OR  N''' + @c_ReplGroup + ''' = ''ALL'')'
                           + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                                     --(Wan02)
                           + '      (SCFG1.Authority = ''1'' AND ISNULL(DEL_REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(DEL_REPLENISHMENT.Wavekey,'''') ='''') )'  --(Wan02)
         END   
      END
      ELSE
      BEGIN
         IF @c_storerkey = 'ALL' 
         BEGIN
            SET @c_ReplSQL = N'DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR'
                           + ' SELECT REPLENISHMENT.ReplenishmentKey'
                           + ' FROM REPLENISHMENT WITH (NOLOCK) '
                           + ' JOIN LOC (NOLOCK) ON (REPLENISHMENT.TOLOC = LOC.LOC)' 
                           + ' LEFT OUTER JOIN STORERCONFIG WITH (NOLOCK)'
                           +                 ' ON (STORERCONFIG.StorerKey = REPLENISHMENT.StorerKey' 
                           +                 ' AND STORERCONFIG.ConfigKey = ''RDTDYNAMICPICK'' AND STORERCONFIG.sValue = ''1'')'
                           + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'              --(Wan02) 
                           + ' WHERE ((REPLENISHMENT.Confirmed = ''N'' AND STORERCONFIG.sVAlue = ''1'') OR (STORERCONFIG.sVAlue IS NULL))'
                           + ' AND (REPLENISHMENT.ReplenishmentGroup <> ''DYNAMIC'')' 
                           + ' AND LOC.Facility = N''' + @c_Facility + ''''
                           + ' AND LOC.PutawayZone IN ( N''' + @c_Zone02 + ''''
                                                    + ',N''' + @c_Zone03 + ''''
                                                    + ',N''' + @c_Zone04 + ''''
                                                    + ',N''' + @c_Zone05 + ''''
                                                    + ',N''' + @c_Zone06 + ''''
                                                    + ',N''' + @c_Zone07 + ''''
                                                    + ',N''' + @c_Zone08 + ''''
                                                    + ',N''' + @c_Zone09 + ''''
                                                    + ',N''' + @c_Zone10 + ''''
                                                    + ',N''' + @c_Zone11 + ''''
                                                    + ',N''' + @c_Zone12 + ''')' 
                           + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                            --(Wan02)                                                           
                           + '      (SCFG1.Authority = ''1'' AND ISNULL(REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(REPLENISHMENT.Wavekey,'''') ='''') )' --(Wan02)                                                                              

            SET @c_ReplDelSQL = N'DECLARE CUR_DELREPL CURSOR FAST_FORWARD READ_ONLY FOR' 
                              + ' SELECT DEL_REPLENISHMENT.RowRef'
                              + ' FROM DEL_REPLENISHMENT WITH (NOLOCK)'           
                              + ' JOIN LOC (NOLOCK) ON (DEL_REPLENISHMENT.TOLOC = LOC.LOC)'
                              + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, DEL_REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'       --(Wan02)  
                              + ' WHERE LOC.Facility = N''' + @c_Facility + ''''
                              + ' AND LOC.PutawayZone IN ( N''' + @c_Zone02 + ''''
                                                       + ',N''' + @c_Zone03 + ''''
                                                       + ',N''' + @c_Zone04 + ''''
                                                       + ',N''' + @c_Zone05 + ''''
                                                       + ',N''' + @c_Zone06 + ''''
                                                       + ',N''' + @c_Zone07 + ''''
                                                       + ',N''' + @c_Zone08 + ''''
                                                       + ',N''' + @c_Zone09 + ''''
                                                       + ',N''' + @c_Zone10 + ''''
                                                       + ',N''' + @c_Zone11 + ''''
                                                       + ',N''' + @c_Zone12 + ''')'                           
                              + ' AND DEL_REPLENISHMENT.DeleteDate < DATEADD(Mi, -10, GETDATE() )'
                              + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                      --(Wan02)
                              + '      (SCFG1.Authority = ''1'' AND ISNULL(DEL_REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(DEL_REPLENISHMENT.Wavekey,'''') ='''') )'  --(Wan02)                               
         END
         ELSE
         BEGIN
            SET @c_ReplSQL = N'DECLARE CUR_REPL CURSOR FAST_FORWARD READ_ONLY FOR'
                           + ' SELECT REPLENISHMENT.ReplenishmentKey'
                           + ' FROM REPLENISHMENT WITH (NOLOCK) '
                           + ' JOIN LOC (NOLOCK) ON (REPLENISHMENT.TOLOC = LOC.LOC)' 
                           + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'              --(Wan02)  
                           + ' WHERE REPLENISHMENT.ReplenishmentGroup <> ''DYNAMIC''' 
                           + ' AND REPLENISHMENT.Storerkey = N''' + @c_Storerkey + ''''                            
                           + ' AND LOC.Facility = N''' + @c_Facility + ''''
                           + ' AND LOC.PutawayZone IN ( N''' + @c_Zone02 + ''''
                                                    + ',N''' + @c_Zone03 + ''''
                                                    + ',N''' + @c_Zone04 + ''''
                                                    + ',N''' + @c_Zone05 + ''''
                                                    + ',N''' + @c_Zone06 + ''''
                                                    + ',N''' + @c_Zone07 + ''''
                                                    + ',N''' + @c_Zone08 + ''''
                                                    + ',N''' + @c_Zone09 + ''''
                                                    + ',N''' + @c_Zone10 + ''''
                                                    + ',N''' + @c_Zone11 + ''''
                                                    + ',N''' + @c_Zone12 + ''')'  
                           + ' AND (REPLENISHMENT.Confirmed = ''N'' OR N''' +  @c_rdtDynamicpick + ''' <> ''1'')'
                           + ' AND (REPLENISHMENT.ReplenishmentGroup = N''' + @c_ReplGroup + ''' OR N''' + @c_ReplGroup + ''' = ''ALL'')'
                           + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                            --(Wan02)
                           + '      (SCFG1.Authority = ''1'' AND ISNULL(REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(REPLENISHMENT.Wavekey,'''') ='''') )' --(Wan02)

            SET @c_ReplDelSQL = N'DECLARE CUR_DELREPL CURSOR FAST_FORWARD READ_ONLY FOR' 
                              + ' SELECT DEL_REPLENISHMENT.RowRef'
                              + ' FROM DEL_REPLENISHMENT WITH (NOLOCK)'           
                              + ' JOIN LOC (NOLOCK) ON (DEL_REPLENISHMENT.TOLOC = LOC.LOC)'
                              + ' CROSS APPLY dbo.fnc_SelectGetRight  (LOC.Facility, DEL_REPLENISHMENT.StorerKey,'''',''DelRegularReplen'') SCFG1'          --(Wan02)  
                              + ' WHERE DEL_REPLENISHMENT.Storerkey = N''' + @c_Storerkey + ''''                             
                              + ' AND LOC.Facility = N''' + @c_Facility + ''''
                              + ' AND LOC.PutawayZone IN ( N''' + @c_Zone02 + ''''
                                                       + ',N''' + @c_Zone03 + ''''
                                                       + ',N''' + @c_Zone04 + ''''
                                                       + ',N''' + @c_Zone05 + ''''
                                                       + ',N''' + @c_Zone06 + ''''
                                                       + ',N''' + @c_Zone07 + ''''
                                                       + ',N''' + @c_Zone08 + ''''
                                                       + ',N''' + @c_Zone09 + ''''
                                                       + ',N''' + @c_Zone10 + ''''
                                                       + ',N''' + @c_Zone11 + ''''
                                                       + ',N''' + @c_Zone12 + ''')' 
                              + ' AND  DEL_REPLENISHMENT.DeleteDate < DATEADD(Mi, -10, GETDATE() )' 
                              + ' AND (DEL_REPLENISHMENT.ReplenishmentGroup = ''' + @c_ReplGroup + ''' OR  N''' + @c_ReplGroup + ''' = ''ALL'')'
                              + ' AND ( SCFG1.Authority = ''0'' OR'                                                                                                     --(Wan02)
                              + '      (SCFG1.Authority = ''1'' AND ISNULL(DEL_REPLENISHMENT.Loadkey,'''') = '''' AND ISNULL(DEL_REPLENISHMENT.Wavekey,'''') ='''') )'  --(Wan02)
         END  
      END
   END

   IF @c_ReplSQL <> ''
   BEGIN
      EXEC (@c_ReplSQL)

      OPEN CUR_REPL
      FETCH NEXT FROM CUR_REPL INTO @c_ReplenishmentKey
      WHILE @@FETCH_STATUS <> -1  
      BEGIN

         DELETE FROM REPLENISHMENT WITH (ROWLOCK)
         WHERE ReplenishmentKey = @c_ReplenishmentKey

         IF @@Error <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63510  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Delete Error on Table Replenishment (isp_DeleteNotConfirmRepl)' + ' ( ' + 
                  ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_REPL INTO @c_ReplenishmentKey
      END
      CLOSE CUR_REPL
      DEALLOCATE CUR_REPL
   END

   IF @c_ReplDelSQL <> '' AND @c_RepleDelLog = '1' 
   BEGIN
      EXEC (@c_ReplDelSQL)

      OPEN CUR_DELREPL
      FETCH NEXT FROM CUR_DELREPL INTO @n_RowRef
      WHILE @@FETCH_STATUS <> -1  
      BEGIN
         UPDATE DEL_REPLENISHMENT WITH (ROWLOCK)
         SET  SourceType = 'POSTING'
            , EditDate = GETDATE()
            , EditWho  = SUSER_NAME()
         WHERE RowRef = @n_RowRef

         IF @@Error <> 0
         BEGIN
            SET @n_continue = 3
            SET @c_errmsg = CONVERT(char(250),@n_err)
            SET @n_err = 63520  
            SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': UPDATE Fail on Table DEL_REPLENISHMENT (isp_DeleteNotConfirmRepl)' + ' ( ' + 
                  ' SQLSvr MESSAGE=' + RTRIM(ISNULL(@c_errmsg,'')) + ' ) '
            GOTO QUIT_SP
         END

         FETCH NEXT FROM CUR_DELREPL INTO @n_RowRef
      END
      CLOSE CUR_DELREPL
      DEALLOCATE CUR_DELREPL
   END

   QUIT_SP:

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_REPL') in (0 , 1)  
   BEGIN
      CLOSE CUR_REPL
      DEALLOCATE CUR_REPL
   END

   IF CURSOR_STATUS( 'GLOBAL', 'CUR_DELREPL') in (0 , 1)  
   BEGIN
      CLOSE CUR_DELREPL
      DEALLOCATE CUR_DELREPL
   END
   --(Wan01) - END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 OR @@TRANCOUNT >= @n_StartTCount
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_DeleteNotConfirmRepl'
--      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
   ELSE
   BEGIN
      SET @b_success = 1
      RETURN
   END 
END

GO