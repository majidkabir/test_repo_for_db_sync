SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/*************************************************************************/
/* Stored Procedure: isp_RPT_WV_PreGenRptDataSP01                        */
/* Creation Date: 06-Dec-2023                                            */
/* Copyright: MAERSK                                                     */
/* Written by: WLChooi                                                   */
/*                                                                       */
/* Purpose: WMS-24329 - CHL - PUMA Generate Consolidated PickSlip        */
/*                                                                       */
/* Called By: WM.lsp_WM_Print_Report                                     */
/*                                                                       */
/* GitHub Version: 1.0                                                   */
/*                                                                       */
/* Version: 5.4                                                          */
/*                                                                       */
/* Data Modifications:                                                   */
/*                                                                       */
/* Updates:                                                              */
/* Date        Author  Ver   Purposes                                    */
/* 06-Dec-2023 WLChooi 1.0   DevOps Combine Script                       */
/* 27-MAR-2024 CSCHONG 1.1   UWP-17313 limit 15 line per pickslipno(CS01)*/
/*************************************************************************/

CREATE   PROC [dbo].[isp_RPT_WV_PreGenRptDataSP01]
(
   @c_Wavekey               NVARCHAR(10)  
 , @c_PickslipType          NVARCHAR(10)  = 'LB'  --Discrete('8', '3', 'D')  Conso('5','6','7','9','C')  Xdock ('XD','LB','LP')
 , @c_Refkeylookup          NVARCHAR(5)   = 'Y'   --Y=Create refkeylookup records  N=Not create
 , @c_LinkPickSlipToPick    NVARCHAR(5)   = 'N'   --Y=Update pickslipno to pickdetail.pickslipno  N=Not update to pickdetail
 , @c_AutoScanIn            NVARCHAR(5)   = 'N'   --Y=Auto scan in the pickslip N=Not auto scan in  
 , @c_GroupMethod           NVARCHAR(500) = 'Loadkey,UOM,Pickzone,@n_maxline = 15'   --Pickslip Group method, for example, Wavekey, Loadkey, UOM, Pickzone,maxline per pickslipno
 , @b_Success               INT  = 1            OUTPUT
 , @n_Err                   INT  = 0            OUTPUT
 , @c_ErrMsg                NVARCHAR(250) = ''  OUTPUT
)
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET NOCOUNT ON

   DECLARE @n_Continue           INT
         , @n_Cnt                INT
         , @n_StartTCnt          INT
         , @c_PickslipNo         NVARCHAR(10)
         , @c_Storerkey          NVARCHAR(15)
         , @n_SeqNo              INT
         , @c_ColValue           NVARCHAR(50)
         , @c_Cols               NVARCHAR(4000) = ''
         , @c_SelectCols         NVARCHAR(4000) = ''
         , @c_GroupCols          NVARCHAR(4000) = ''
         , @c_SQL                NVARCHAR(MAX) = ''
         , @c_ExecArguments      NVARCHAR(MAX) = ''
         , @c_Orderkey           NVARCHAR(10)
         , @c_Loadkey            NVARCHAR(10)
         , @c_UOM                NVARCHAR(10)
         , @c_Pickzone           NVARCHAR(50)
         , @c_CursorVar          NVARCHAR(50)
         , @c_CursorVarList      NVARCHAR(4000) = ''
         , @n_RowID              INT
         , @c_PH_Wavekey         NVARCHAR(20)   --CS01
         , @c_PickDetailKey      NVARCHAR(10)
         , @c_PH_ConsoOrderkey   NVARCHAR(50)
         , @b_Debug              INT = 0
         , @c_GetWavekey         NVARCHAR(10) = ''
         , @n_Linecount          INT   --CS01
         , @n_MaxLine            INT   --CS01
         , @n_RecGrp             INT   --CS01 

   DECLARE @CUR_PickDetail CURSOR 

   SET @b_Debug = @n_Err

   SELECT @n_Continue = 1, @n_StartTCnt = @@TRANCOUNT, @n_Err = 0, @c_ErrMsg = '', @b_Success = 1

   
   SELECT @n_MaxLine = dbo.fnc_GetParamValueFromString('@n_maxline', @c_GroupMethod, '') --CS01 S

   IF @n_MaxLine = 0
   BEGIN
      SET @n_MaxLine = 1
   END
   --CS01 E

   CREATE TABLE #TMP_DICT ( 
      RowID       INT NOT NULL IDENTITY(1,1)
    , DictKey     NVARCHAR(100)
    , DictValue   NVARCHAR(100)
    , DictVar     NVARCHAR(100) 
   )

   CREATE TABLE #TMP_DATA ( 
      Wavekey          NVARCHAR(100) NULL
    , Loadkey          NVARCHAR(100) NULL
    , Orderkey         NVARCHAR(100) NULL
    , UOM              NVARCHAR(100) NULL
    , Pickzone         NVARCHAR(100) NULL
    , RecGrp           INT    
  , PickDetailKey    NVARCHAR(20) NULL
   )

   INSERT INTO #TMP_DICT (DictKey, DictValue, DictVar)
   SELECT 'WAVEKEY', 'WAVEDETAIL.Wavekey', 'Wavekey'
   UNION ALL
   SELECT 'WAVE', 'WAVEDETAIL.Wavekey', 'Wavekey'
   UNION ALL
   SELECT 'LOADKEY', 'LOADPLANDETAIL.Loadkey', 'Loadkey'
   UNION ALL
   SELECT 'LOAD', 'LOADPLANDETAIL.Loadkey', 'Loadkey'
   UNION ALL
   SELECT 'ORDERKEY', 'WAVEDETAIL.ORDERKEY', 'Orderkey'
   UNION ALL
   SELECT 'ORDER', 'WAVEDETAIL.ORDERKEY', 'Orderkey'
   UNION ALL
   SELECT 'UOM', 'PICKDETAIL.UOM', 'UOM'
   UNION ALL
   SELECT 'PICKZONE', 'LOC.Pickzone', 'Pickzone'
   
   SELECT TOP 1 @c_Storerkey = OH.Storerkey
   FROM WAVEDETAIL WD (NOLOCK)
   JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
   WHERE WD.WaveKey = @c_Wavekey

   --Construct the select statement
   DECLARE CUR_DELIM CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT F.SeqNo
        , IIF(ISNULL(T.DictValue, '') = '', TRIM(F.ColValue), T.DictValue)
        , ISNULL(T.DictVar, '')
        , T.RowID
   FROM dbo.fnc_DelimSplit(',', @c_GroupMethod) F
   JOIN #TMP_DICT T ON T.DictKey = F.ColValue
   ORDER BY T.RowID

   OPEN CUR_DELIM

   FETCH NEXT FROM CUR_DELIM INTO @n_SeqNo, @c_ColValue, @c_CursorVar, @n_RowID

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      IF ISNULL(@c_Cols, '') = ''
      BEGIN
         SET @c_Cols = @c_ColValue
      END
      ELSE
      BEGIN
         SET @c_Cols = @c_Cols + ', ' + @c_ColValue
      END

      IF ISNULL(@c_CursorVar, '') = ''
      BEGIN
         SET @c_CursorVar = SUBSTRING(@c_ColValue, CHARINDEX('.', @c_ColValue) + 1, LEN(@c_ColValue) - CHARINDEX('.', @c_ColValue) + 1)
      END

      IF ISNULL(@c_CursorVarList, '') = ''
      BEGIN
         SET @c_CursorVarList = @c_CursorVar
      END
      ELSE
      BEGIN
         SET @c_CursorVarList = @c_CursorVarList + ', ' + @c_CursorVar
      END

      FETCH NEXT FROM CUR_DELIM INTO @n_SeqNo, @c_ColValue, @c_CursorVar, @n_RowID
   END
   CLOSE CUR_DELIM
   DEALLOCATE CUR_DELIM

   SET @c_CursorVarList = N'INSERT INTO #TMP_DATA ( ' + @c_CursorVarList + ',RecGrp,PickDetailKey' +')'
   SET @c_SelectCols = 'SELECT ' + @c_Cols + ',(ROW_NUMBER() OVER (PARTITION BY ' + @c_Cols +   
                                      ' ORDER BY '  + @c_Cols + ')-1)   /@n_MaxLine + 1,PICKDETAIL.PickDetailKey '
   SET @c_GroupCols = 'GROUP BY ' + @c_Cols

   SELECT @c_SQL = @c_CursorVarList + CHAR(13)
                 + @c_SelectCols + CHAR(13)
                 + N'FROM WAVEDETAIL WITH (NOLOCK) ' + CHAR(13)
                 + N'JOIN ORDERS WITH (NOLOCK) ON (WAVEDETAIL.OrderKey = ORDERS.OrderKey) ' + CHAR(13)
                 + N'JOIN PICKDETAIL WITH (NOLOCK) ON (PICKDETAIL.OrderKey = ORDERS.OrderKey) ' + CHAR(13)
                 + N'JOIN LoadPlanDetail WITH (NOLOCK) ON (LoadPlanDetail.OrderKey = PICKDETAIL.OrderKey) ' + CHAR(13)
                 + N'JOIN LoadPlan WITH (NOLOCK) ON (LoadPlan.LoadKey = LoadPlanDetail.LoadKey) ' + CHAR(13)
                 + N'JOIN LOC WITH (NOLOCK) ON (PICKDETAIL.Loc = LOC.Loc) ' + CHAR(13)
                 + N'WHERE WAVEDETAIL.Wavekey = @c_Wavekey ' + CHAR(13)
                 + N'AND PICKDETAIL.Status < ''5'' ' + CHAR(13)
               --  + @c_GroupCols

   SET @c_ExecArguments = N'   @c_Wavekey         NVARCHAR(10) '
                        + N' , @c_Orderkey        NVARCHAR(10) '
                        + N' , @c_Loadkey         NVARCHAR(10) '
                        + N' , @c_UOM             NVARCHAR(10) '
                        + N' , @c_Pickzone        NVARCHAR(50) '
                        + N' , @n_MaxLine         INT'
        
   EXEC sp_ExecuteSql @c_SQL       
                    , @c_ExecArguments 
                    , @c_Wavekey
                    , @c_Orderkey
                    , @c_Loadkey 
                    , @c_UOM     
                    , @c_Pickzone
                    , @n_MaxLine

   DECLARE CUR_GENPS CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT distinct ISNULL(Wavekey, ''), ISNULL(Loadkey, ''), ISNULL(Orderkey, ''), ISNULL(UOM, ''), ISNULL(Pickzone, ''),RecGrp   --CS01
   FROM #TMP_DATA
   GROUP BY ISNULL(Wavekey, ''), ISNULL(Loadkey, ''), ISNULL(Orderkey, ''), ISNULL(UOM, ''), ISNULL(Pickzone, ''),RecGrp  --CS01
   Order by ISNULL(Wavekey, ''), ISNULL(Loadkey, ''), ISNULL(Orderkey, ''), ISNULL(UOM, ''), ISNULL(Pickzone, ''),RecGrp  --CS01

   OPEN CUR_GENPS

   FETCH NEXT FROM CUR_GENPS INTO @c_GetWavekey, @c_Loadkey, @c_Orderkey, @c_UOM, @c_Pickzone,@n_RecGrp                --CS01

   WHILE @@FETCH_STATUS <> -1
   BEGIN
      SET @c_PickslipNo = ''
      SET @c_PH_Wavekey = ''
      SET @c_PH_ConsoOrderkey = ''
      
      IF CURSOR_STATUS('LOCAL', '@CUR_PickDetail') IN (0 , 1)
      BEGIN    
         CLOSE @CUR_PickDetail
         DEALLOCATE @CUR_PickDetail
      END

      IF @c_Pickzone = ''  AND @c_UOM <> '' OR --If split by UOM
         @c_Pickzone <> '' AND @c_UOM <> ''   --If split by Pickzone + UOM
      BEGIN
         IF @c_UOM = '1'
         BEGIN
            SET @c_PH_Wavekey = TRIM(@c_PickZone) + CAST(@n_RecGrp as nvarchar(2)) + '_P'   --CS01
         END
         ELSE IF @c_UOM = '2'
         BEGIN
            SET @c_PH_Wavekey = TRIM(@c_PickZone) + CAST(@n_RecGrp as nvarchar(2)) + '_C'   --CS01
         END
         ELSE IF @c_UOM = '7'
         BEGIN
            SET @c_PH_Wavekey = TRIM(@c_PickZone) + CAST(@n_RecGrp as nvarchar(2)) + '_7'   --CS01
         END
         ELSE
         BEGIN
            SET @c_PH_Wavekey = TRIM(@c_PickZone) + CAST(@n_RecGrp as nvarchar(2))          --CS01
         END
      END
      ELSE IF @c_Pickzone <> '' AND @c_UOM = ''   --If split by Pickzone
      BEGIN
         SET @c_PH_Wavekey = TRIM(@c_PickZone) + CAST(@n_RecGrp as nvarchar(2))     --CS01
      END

      IF @c_Orderkey <> '' --create discrete pickslip
      BEGIN
         SELECT @c_PickslipNo = PickHeaderKey
         FROM PICKHEADER (NOLOCK)
         WHERE OrderKey = @c_Orderkey

         SET @CUR_PickDetail = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PICKDETAIL.PickDetailKey
         FROM PICKDETAIL WITH (NOLOCK)
         WHERE PICKDETAIL.OrderKey = @c_Orderkey
         ORDER BY PICKDETAIL.PickDetailKey
      END
      ELSE IF @c_Loadkey <> ''   --Conso by Load
      BEGIN
         SELECT @c_Pickslipno = Pickheaderkey
         FROM PICKHEADER(NOLOCK) 
         WHERE ExternOrderkey = @c_Loadkey 
         AND ISNULL(Orderkey,'') = ''
         AND WaveKey = @c_PH_Wavekey

         SET @CUR_PickDetail = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PICKDETAIL.PickDetailKey
         FROM PICKDETAIL (NOLOCK)  
         JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey  
         JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.Loc
         WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey  
         AND PICKDETAIL.Pickslipno <> @c_Pickslipno 
         AND PICKDETAIL.UOM = CASE WHEN @c_UOM = '' THEN PICKDETAIL.UOM ELSE @c_UOM END
         AND LOC.PickZone = CASE WHEN @c_Pickzone = '' THEN LOC.PickZone ELSE @c_Pickzone END
      END
      ELSE IF @c_GetWavekey <> ''   --Conso by Wave
      BEGIN
         SELECT @c_Pickslipno = Pickheaderkey
         FROM PICKHEADER(NOLOCK) 
         WHERE Wavekey = @c_GetWavekey 
         AND ISNULL(Orderkey,'') = ''
         AND ConsoOrderKey = @c_PH_Wavekey

         SET @CUR_PickDetail = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT PICKDETAIL.PickDetailKey
         FROM PICKDETAIL (NOLOCK)  
         JOIN Wavedetail (NOLOCK) ON PICKDETAIL.Orderkey = Wavedetail.Orderkey  
         JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.Loc
         JOIN #TMP_DATA TD ON TD.pickdetailkey = PICKDETAIL.PickDetailKey    --CS01
         WHERE Wavedetail.WaveKey = @c_GetWavekey  
         AND PICKDETAIL.Pickslipno <> @c_Pickslipno 
         AND PICKDETAIL.UOM = CASE WHEN @c_UOM = '' THEN PICKDETAIL.UOM ELSE @c_UOM END
         AND LOC.PickZone = CASE WHEN @c_Pickzone = '' THEN LOC.PickZone ELSE @c_Pickzone END
         AND TD.Recgrp = @n_Recgrp

         SET @c_PH_ConsoOrderkey = @c_PH_Wavekey
         SET @c_PH_Wavekey = @c_GetWavekey
      END

      IF ISNULL(@c_PickslipNo, '') = ''
      BEGIN
         EXECUTE nspg_GetKey 'PICKSLIP'
                           , 9
                           , @c_PickslipNo OUTPUT
                           , @b_Success OUTPUT
                           , @n_Err OUTPUT
                           , @c_ErrMsg OUTPUT
      
         SELECT @c_PickslipNo = 'P' + @c_PickslipNo
      
         INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, OrderKey, PickType, [Zone], StorerKey, WaveKey, ConsoOrderKey)
         VALUES (@c_PickslipNo, @c_Loadkey, @c_Orderkey, '0', @c_PickslipType, @c_Storerkey, @c_PH_Wavekey, @c_PH_ConsoOrderkey)
      
         SELECT @n_Err = @@ERROR
         IF @n_Err <> 0
         BEGIN
            SELECT @n_Continue = 3
            SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                 , @n_Err = 83500 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err) + ': Insert PICKHEADER Failed (isp_RPT_WV_PreGenRptDataSP01)'
                               + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_ErrMsg) + ' ) '
            GOTO QUIT_SP
         END
      END
      ELSE
      BEGIN
         UPDATE PICKHEADER WITH (ROWLOCK)
         SET PickType = '1'
           , TrafficCop = NULL
         WHERE Pickheaderkey = @c_PickslipNo AND PickType = '0'

         IF @@ERROR <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 83501
            SET @c_errmsg = N'NSQL' + CONVERT(NVARCHAR(5), @n_err)
                            + N': Update Failed On Table Pickheader Table. (isp_RPT_WV_PreGenRptDataSP01)' + N' ( '
                            + N' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + N' ) '
            GOTO QUIT_SP
         END
      END

      IF @c_LinkPickSlipToPick = 'Y' AND @n_Continue IN ( 1, 2 )
      BEGIN
         IF @c_Orderkey <> ''
         BEGIN
            SET @CUR_PickDetail = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PICKDETAIL.PickDetailKey
            FROM PICKDETAIL WITH (NOLOCK)
            JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.Loc
            WHERE PICKDETAIL.OrderKey = @c_Orderkey
            AND PICKDETAIL.Pickslipno <> @c_Pickslipno 
            AND PICKDETAIL.UOM = CASE WHEN @c_UOM = '' THEN PICKDETAIL.UOM ELSE @c_UOM END
            AND LOC.PickZone = CASE WHEN @c_Pickzone = '' THEN LOC.PickZone ELSE @c_Pickzone END
            ORDER BY PICKDETAIL.PickDetailKey
         END
         ELSE IF @c_Loadkey <> ''   --Conso by Load
         BEGIN
            SET @CUR_PickDetail = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PICKDETAIL.PickDetailKey
            FROM PICKDETAIL (NOLOCK)  
            JOIN LOADPLANDETAIL (NOLOCK) ON PICKDETAIL.Orderkey = LOADPLANDETAIL.Orderkey  
            JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.Loc
            WHERE LOADPLANDETAIL.Loadkey = @c_Loadkey  
            AND PICKDETAIL.Pickslipno <> @c_Pickslipno 
            AND PICKDETAIL.UOM = CASE WHEN @c_UOM = '' THEN PICKDETAIL.UOM ELSE @c_UOM END
            AND LOC.PickZone = CASE WHEN @c_Pickzone = '' THEN LOC.PickZone ELSE @c_Pickzone END
            ORDER BY PICKDETAIL.PickDetailKey
         END
         ELSE IF @c_GetWavekey <> ''   --Conso by Wave
         BEGIN
            SET @CUR_PickDetail = CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT PICKDETAIL.PickDetailKey
            FROM PICKDETAIL (NOLOCK)  
            JOIN Wavedetail (NOLOCK) ON PICKDETAIL.Orderkey = Wavedetail.Orderkey  
            JOIN LOC (NOLOCK) ON LOC.LOC = PICKDETAIL.Loc
            JOIN #TMP_DATA TD ON TD.pickdetailkey = PICKDETAIL.PickDetailKey                 --CS01
            WHERE Wavedetail.WaveKey = @c_GetWavekey  
            AND PICKDETAIL.Pickslipno <> @c_Pickslipno 
            AND PICKDETAIL.UOM = CASE WHEN @c_UOM = '' THEN PICKDETAIL.UOM ELSE @c_UOM END
            AND LOC.PickZone = CASE WHEN @c_Pickzone = '' THEN LOC.PickZone ELSE @c_Pickzone END
            AND TD.RecGrp = @n_RecGrp                                                        --CS01
            ORDER BY PICKDETAIL.PickDetailKey
         END

         OPEN @CUR_PickDetail

         FETCH NEXT FROM @CUR_PickDetail
         INTO @c_PickDetailKey

         WHILE @@FETCH_STATUS <> -1 AND @n_Continue IN ( 1, 2 )
         BEGIN
            UPDATE PICKDETAIL WITH (ROWLOCK)
            SET PickSlipNo = @c_PickslipNo
              , TrafficCop = NULL
            WHERE PickSlipNo <> @c_PickslipNo 
            AND PickDetailKey = @c_PickDetailKey

            SELECT @n_Err = @@ERROR

            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83505 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Update PICKDETAIL Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END

            FETCH NEXT FROM @CUR_PickDetail
            INTO @c_PickDetailKey
         END
         CLOSE @CUR_PickDetail
         DEALLOCATE @CUR_PickDetail
      END

      IF @c_Refkeylookup = 'Y' AND @n_Continue IN ( 1, 2 )
      BEGIN
         IF @c_Orderkey <> ''
         BEGIN
            INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber, Loadkey)
            SELECT PD.PickDetailKey
                 , @c_PickslipNo
                 , PD.OrderKey
                 , PD.OrderLineNumber
                 , @c_Loadkey
            FROM PICKDETAIL PD (NOLOCK)
            JOIN LOC L (NOLOCK) ON L.LOC = PD.Loc
            LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.PickDetailKey = RKL.PickDetailkey

            WHERE PD.OrderKey = @c_Orderkey AND RKL.PickDetailkey IS NULL
            AND PD.UOM = CASE WHEN @c_UOM = '' THEN PD.UOM ELSE @c_UOM END
            AND L.PickZone = CASE WHEN @c_Pickzone = '' THEN L.PickZone ELSE @c_Pickzone END

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83510 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Insert RefKeyLookUp Table Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END

            UPDATE RefKeyLookup WITH (ROWLOCK)
            SET RefKeyLookup.Pickslipno = @c_PickslipNo
            FROM PICKDETAIL PD (NOLOCK)
            JOIN LOC L (NOLOCK) ON L.LOC = PD.Loc
            JOIN RefKeyLookup ON PD.PickDetailKey = RefKeyLookup.PickDetailkey
            WHERE PD.OrderKey = @c_Orderkey AND RefKeyLookup.Pickslipno <> @c_PickslipNo
            AND PD.UOM = CASE WHEN @c_UOM = '' THEN PD.UOM ELSE @c_UOM END
            AND L.PickZone = CASE WHEN @c_Pickzone = '' THEN L.PickZone ELSE @c_Pickzone END


            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83515 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Update RefKeyLookUp Table Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END
         END
         ELSE IF @c_Loadkey <> ''
         BEGIN
            INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber)
            SELECT PD.PickDetailKey
                 , @c_PickslipNo
                 , PD.OrderKey
                 , PD.OrderLineNumber
            FROM LoadPlanDetail LD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON LD.OrderKey = PD.OrderKey
            JOIN LOC L (NOLOCK) ON L.LOC = PD.Loc
            LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.PickDetailKey = RKL.PickDetailkey
            WHERE LD.LoadKey = @c_Loadkey AND RKL.PickDetailkey IS NULL
            AND PD.UOM = CASE WHEN @c_UOM = '' THEN PD.UOM ELSE @c_UOM END
            AND L.PickZone = CASE WHEN @c_Pickzone = '' THEN L.PickZone ELSE @c_Pickzone END

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83520 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Insert RefKeyLookUp Table Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END

            UPDATE RefKeyLookup WITH (ROWLOCK)
            SET RefKeyLookup.Pickslipno = @c_PickslipNo
            FROM LoadPlanDetail LD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON LD.OrderKey = PD.OrderKey
            JOIN LOC L (NOLOCK) ON L.LOC = PD.Loc
            JOIN RefKeyLookup ON PD.PickDetailKey = RefKeyLookup.PickDetailkey
            WHERE LD.LoadKey = @c_Loadkey 
            AND RefKeyLookup.Pickslipno <> @c_PickslipNo
            AND PD.UOM = CASE WHEN @c_UOM = '' THEN PD.UOM ELSE @c_UOM END
            AND L.PickZone = CASE WHEN @c_Pickzone = '' THEN L.PickZone ELSE @c_Pickzone END

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83525 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Update RefKeyLookUp Table Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END
         END
         ELSE IF @c_GetWavekey <> ''
         BEGIN   

            INSERT INTO RefKeyLookup (PickDetailkey, Pickslipno, OrderKey, OrderLineNumber)
            SELECT PD.PickDetailKey
                 , @c_PickslipNo
                 , PD.OrderKey
                 , PD.OrderLineNumber
            FROM Wavedetail WD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON WD.OrderKey = PD.OrderKey
            JOIN LOC L (NOLOCK) ON L.LOC = PD.Loc
            LEFT JOIN RefKeyLookup RKL (NOLOCK) ON PD.PickDetailKey = RKL.PickDetailkey
            JOIN #TMP_DATA TD ON TD.pickdetailkey = PD.PickDetailKey                 --CS01
            WHERE WD.WaveKey = @c_GetWavekey AND RKL.PickDetailkey IS NULL
            AND PD.UOM = CASE WHEN @c_UOM = '' THEN PD.UOM ELSE @c_UOM END
            AND L.PickZone = CASE WHEN @c_Pickzone = '' THEN L.PickZone ELSE @c_Pickzone END
            AND TD.RecGrp = @n_RecGrp                                                        --CS01

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83530 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Insert RefKeyLookUp Table Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END

            UPDATE RefKeyLookup WITH (ROWLOCK)
            SET RefKeyLookup.Pickslipno = @c_PickslipNo
            FROM Wavedetail WD (NOLOCK)
            JOIN PICKDETAIL PD (NOLOCK) ON WD.OrderKey = PD.OrderKey
            JOIN LOC L (NOLOCK) ON L.LOC = PD.Loc
            JOIN RefKeyLookup ON PD.PickDetailKey = RefKeyLookup.PickDetailkey
            JOIN #TMP_DATA TD ON TD.pickdetailkey = PD.PickDetailKey                 --CS01
            WHERE WD.WaveKey = @c_GetWavekey AND RefKeyLookup.Pickslipno <> @c_PickslipNo
            AND PD.UOM = CASE WHEN @c_UOM = '' THEN PD.UOM ELSE @c_UOM END
            AND L.PickZone = CASE WHEN @c_Pickzone = '' THEN L.PickZone ELSE @c_Pickzone END
            AND TD.RecGrp = @n_RecGrp                                                        --CS01

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83535 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Update RefKeyLookUp Table Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END
         END
      END

      IF @c_AutoScanIn = 'Y'
      BEGIN
         IF NOT EXISTS (  SELECT 1
                          FROM PickingInfo (NOLOCK)
                          WHERE PickSlipNo = @c_PickslipNo)
         BEGIN
            INSERT INTO PickingInfo (PickSlipNo, ScanInDate)
            VALUES (@c_PickslipNo, GETDATE())

            SELECT @n_Err = @@ERROR
            IF @n_Err <> 0
            BEGIN
               SELECT @n_Continue = 3
               SELECT @c_ErrMsg = CONVERT(NVARCHAR(250), @n_Err)
                    , @n_Err = 83540 -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
               SELECT @c_ErrMsg = 'NSQL' + CONVERT(NVARCHAR(5), @n_Err)
                                  + ': Insert PickingInfo Table Failed (isp_RPT_WV_PreGenRptDataSP01)' + ' ( ' + ' SQLSvr MESSAGE='
                                  + RTRIM(@c_ErrMsg) + ' ) '
               GOTO QUIT_SP
            END
         END
      END

      FETCH NEXT FROM CUR_GENPS INTO @c_GetWavekey, @c_Loadkey, @c_Orderkey, @c_UOM, @c_Pickzone ,@n_RecGrp                --CS01
   END
   CLOSE CUR_GENPS
   DEALLOCATE CUR_GENPS

   IF @b_Debug = 1
      SELECT * FROM #TMP_DATA

   QUIT_SP:
   IF CURSOR_STATUS('LOCAL', '@CUR_PickDetail') IN (0 , 1)
   BEGIN    
      CLOSE @CUR_PickDetail
      DEALLOCATE @CUR_PickDetail
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_GENPS') IN (0 , 1)
   BEGIN    
      CLOSE CUR_GENPS
      DEALLOCATE CUR_GENPS
   END

   IF CURSOR_STATUS('LOCAL', 'CUR_DELIM') IN (0 , 1)
   BEGIN    
      CLOSE CUR_DELIM
      DEALLOCATE CUR_DELIM
   END

   IF OBJECT_ID('tempdb..#TMP_DATA') IS NOT NULL
      DROP TABLE #TMP_DATA
   
   IF OBJECT_ID('tempdb..#TMP_DICT') IS NOT NULL
      DROP TABLE #TMP_DICT

   IF @n_continue = 3
   BEGIN
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'isp_RPT_WV_PreGenRptDataSP01'
      RAISERROR(@c_errmsg, 16, 1) WITH SETERROR
   END
   ELSE
   BEGIN
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
   END
END

GO