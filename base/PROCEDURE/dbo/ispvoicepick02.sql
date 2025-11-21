SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispVoicePick02                                        */
/* Creation Date: 12-Jul-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:  WLChooi                                                    */
/*                                                                         */
/* Purpose: WMS-17427 & WMS-17362 - [CN] Voice Picking General Trigger     */
/*          Logic - B2B                                                    */
/*                                                                         */
/* Called By: isp_BackendVoicePickRelease                                  */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/***************************************************************************/  
CREATE PROC [dbo].[ispVoicePick02]  
(     @c_Storerkey     NVARCHAR(15)
  ,   @c_Facility      NVARCHAR(5)
  ,   @c_FilterField   NVARCHAR(4000) = ''
  ,   @c_FilterValue   NVARCHAR(4000) = ''
  ,   @b_Success       INT             OUTPUT
  ,   @n_Err           INT             OUTPUT
  ,   @c_ErrMsg        NVARCHAR(250)   OUTPUT 
  ,   @b_debug         INT   
)  
AS  
BEGIN  
   SET NOCOUNT ON  
   SET QUOTED_IDENTIFIER OFF  
   SET ANSI_NULLS OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_Continue           INT 
         , @n_StartTCnt          INT 
         , @c_SQL                NVARCHAR(4000) = ''
         , @c_SQLParm            NVARCHAR(4000) = ''

   DECLARE @c_Loadkey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         , @c_Pickslipno      NVARCHAR(10)
         , @c_TransmitLogKey  NVARCHAR(10)
         , @c_Field           NVARCHAR(100)
         , @c_Value           NVARCHAR(100)
         , @c_FilterString    NVARCHAR(4000) = ''
         , @c_FilterString2   NVARCHAR(4000) = ''
         , @c_FilterString3   NVARCHAR(4000) = ''
         , @c_UpdateString    NVARCHAR(4000) = ''
         , @c_UpdateCFMString NVARCHAR(4000) = ''

   DECLARE @c_Short          NVARCHAR(100) = ''
         , @c_UDF01          NVARCHAR(100) = ''
         , @c_UDF02          NVARCHAR(100) = ''
         , @n_RowCount       INT = 0
         , @n_ResultRowCnt   INT = 0
         , @c_Conso          NVARCHAR(1) = 'N'
       
   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  
   
   CREATE TABLE #TMP_Data (
      Loadkey       NVARCHAR(10) NULL,
      Pickheaderkey NVARCHAR(10) NULL 
   )

   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      DECLARE CUR_SPLIT CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      SELECT TRIM(ISNULL(A.[ColValue],'')), TRIM(ISNULL(B.[ColValue],''))
      FROM dbo.fnc_DelimSplit(',', @c_FilterField) A
      JOIN dbo.fnc_DelimSplit(',', @c_FilterValue) B ON A.SeqNo = B.SeqNo 

      OPEN CUR_SPLIT
      
      FETCH NEXT FROM CUR_SPLIT INTO @c_Field, @c_Value
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         SET @c_FilterString    = @c_FilterString + 'AND ' + @c_Field + ' = ''' + @c_Value + ''' ' + CHAR(13)
         SET @c_FilterString2   = @c_FilterString2 + 'AND ' + SUBSTRING(@c_Field, CHARINDEX('.', @c_Field) + 1, LEN(@c_Field) ) + ' <> ''' + @c_Value + ''' ' + CHAR(13) 
         SET @c_FilterString3   = @c_FilterString3 + 'AND ISNULL(' + SUBSTRING(@c_Field, CHARINDEX('.', @c_Field) + 1, LEN(@c_Field) ) + ', '''') = '''' ' + CHAR(13) 
         SET @c_UpdateString    = @c_UpdateString + ', ' + SUBSTRING(@c_Field, CHARINDEX('.', @c_Field) + 1, LEN(@c_Field) ) + ' = ''' + @c_Value + ''' ' + CHAR(13)
         SET @c_UpdateCFMString = @c_UpdateCFMString + ', ' + SUBSTRING(@c_Field, CHARINDEX('.', @c_Field) + 1, LEN(@c_Field) ) + ' = ''' + TRIM(@c_Value) + 'CFM' + ''' ' + CHAR(13)

         FETCH NEXT FROM CUR_SPLIT INTO @c_Field, @c_Value
      END
      CLOSE CUR_SPLIT
      DEALLOCATE CUR_SPLIT
   END

   IF @b_debug = 2
   BEGIN
      SELECT @c_FilterString    AS FilterString   
           , @c_FilterString2   AS FilterString2  
           , @c_FilterString3   AS FilterString3
           , @c_UpdateString    AS UpdateString   
           , @c_UpdateCFMString AS UpdateCFMString
   END

   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      SET @c_SQL = N' DECLARE cur_Loadkey CURSOR FAST_FORWARD READ_ONLY FOR
                         SELECT DISTINCT LOADPLAN.Loadkey, LOADPLAN.Facility
                         FROM ORDERS (NOLOCK)
                         JOIN LOADPLANDETAIL (NOLOCK) ON ORDERS.OrderKey = LOADPLANDETAIL.OrderKey
                         JOIN LOADPLAN (NOLOCK) ON LOADPLAN.LoadKey = LOADPLANDETAIL.LoadKey
                         WHERE ORDERS.StorerKey = @c_Storerkey AND LOADPLAN.[Status] < ''5'' AND ORDERS.DocType <> ''E''
                         AND ORDERS.Facility = CASE WHEN ISNULL(@c_Facility,'''') = '''' THEN ORDERS.Facility ELSE @c_Facility END
                         AND LOADPLAN.EditDate <= CONVERT(DATETIME, DATEADD(MINUTE, -2, GETDATE() ) , 120 ) ' + @c_FilterString

      SET @c_SQLParm =  N'@c_Storerkey    NVARCHAR(15)
                        , @c_Facility     NVARCHAR(5) '
       
      EXEC sp_ExecuteSQL @c_SQL
                       , @c_SQLParm
                       , @c_Storerkey
                       , @c_Facility
      
      OPEN cur_Loadkey

      FETCH NEXT FROM cur_Loadkey INTO @c_Loadkey, @c_Facility
      
      WHILE @@FETCH_STATUS <> -1
      BEGIN
         INSERT INTO #TMP_Data (Loadkey, Pickheaderkey)
         SELECT DISTINCT @c_Loadkey, PH.PickHeaderKey
         FROM LOADPLANDETAIL LPD (NOLOCK)
         JOIN ORDERS OH (NOLOCK) ON OH.OrderKey = LPD.OrderKey
         JOIN PICKHEADER PH (NOLOCK) ON PH.Orderkey = OH.Orderkey
         WHERE LPD.LoadKey = @c_Loadkey

         IF NOT EXISTS (SELECT 1 FROM #TMP_Data WHERE Loadkey = @c_Loadkey)
         BEGIN
            INSERT INTO #TMP_Data (Loadkey, Pickheaderkey)
            SELECT DISTINCT @c_Loadkey, PH.PickHeaderKey
            FROM LOADPLANDETAIL LPD (NOLOCK)
            JOIN PICKHEADER PH (NOLOCK) ON PH.ExternOrderKey = LPD.LoadKey
            WHERE LPD.LoadKey = @c_Loadkey

            SET @c_Conso = 'Y'
         END

         DECLARE cur_Pickheaderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
            SELECT DISTINCT T.Pickheaderkey
            FROM #TMP_Data T
            WHERE T.Loadkey = @c_Loadkey
      
         OPEN cur_Pickheaderkey
         
         FETCH NEXT FROM cur_Pickheaderkey INTO @c_Pickslipno
         
         WHILE @@FETCH_STATUS <> -1
         BEGIN
            SET @c_Short = ''
            SET @c_UDF01 = ''
            SET @n_RowCount = 0

            SELECT TOP 1 @c_Short     = ISNULL(CL.Short,'')   --LocationCategory
                       , @c_UDF01     = ISNULL(CL.UDF01,'')   --LocationType
                       , @c_UDF02     = ISNULL(CL.UDF02,'')   --Act as a switch if need to check LocationCategory and/or LocationType
            FROM CODELKUP CL (NOLOCK)
            WHERE CL.LISTNAME = 'BlocLocCat' AND CL.Code = @c_Facility
            AND CL.Storerkey = @c_Storerkey

            --Multiple Orderkey may appear in 1 Pickslipno/TaskBatchno
            --If one of the orderkey can link with Codelkup, which mean do not generate Transmitlog2 for this Pickslipno
            SELECT @n_RowCount = COUNT(1)
            FROM PICKDETAIL PD (NOLOCK)
            JOIN LOC (NOLOCK) ON LOC.Loc = PD.Loc
            WHERE PD.PickSlipNo = @c_Pickslipno
            AND (LOC.LocationCategory IN (SELECT ColValue from dbo.fnc_delimsplit (',',@c_Short)) 
                  OR LOC.LocationType IN (SELECT ColValue from dbo.fnc_delimsplit (',',@c_UDF01)))

            IF (@n_RowCount = 0 AND @c_UDF02 = 'Y') OR ISNULL(@c_UDF02,'') = ''
            BEGIN
               SET @c_SQL = N'SELECT @n_ResultRowCnt = COUNT(1) 
            	               FROM LOADPLANDETAIL LPD (NOLOCK) 
            	               JOIN PICKDETAIL PD (NOLOCK) ON PD.OrderKey = LPD.OrderKey
            	               WHERE PD.PickSlipNo = @c_Pickslipno  ' + @c_FilterString3

               SET @c_SQLParm =  N'@c_Pickslipno    NVARCHAR(10)
                                 , @n_ResultRowCnt  INT           OUTPUT '

               EXEC sp_ExecuteSQL @c_SQL
                                , @c_SQLParm
                                , @c_Pickslipno
                                , @n_ResultRowCnt   OUTPUT

            	IF @n_ResultRowCnt > 0
      	      BEGIN
                  IF @c_Conso = 'Y'
                  BEGIN
      	            --Insert Transmitlog2
      	            SELECT @b_success = 1
                     
                     EXECUTE nspg_getkey      
                           'TransmitLogKey2'      
                           , 10      
                           , @c_TransmitLogKey OUTPUT      
                           , @b_success        OUTPUT      
                           , @n_err            OUTPUT      
                           , @c_errmsg         OUTPUT      
                     
                     IF NOT @b_success = 1      
                     BEGIN      
                        SET @n_continue = 3      
                        SET @n_err = 71800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                        SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispVoicePick02)' + 
                                        ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
                        GOTO QUIT_SP  
                     END 
                     
                     INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                     SELECT @c_TransmitLogKey, 'WSPICKVCLOG', @c_Pickslipno, @c_Loadkey, @c_Storerkey, '0'
                     
                     SELECT @n_err = @@ERROR  
                     
                     IF @n_err <> 0  
                     BEGIN
                        SELECT @n_continue = 3  
                        SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=71805    
                        SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                         + ': Insert Failed On Table TRANSMITLOG2. (ispVoicePick02)'   
                                         + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
                     END 
                  END
                  
                  DECLARE cur_Orderkey CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
                     SELECT DISTINCT PH.Orderkey
                     FROM PICKHEADER PH (NOLOCK)
                     WHERE PH.PickHeaderKey = @c_Pickslipno
                  
                  OPEN cur_Orderkey
                  
                  FETCH NEXT FROM cur_Orderkey INTO @c_Orderkey
                  
                  WHILE @@FETCH_STATUS <> -1
                  BEGIN
                     IF @c_Conso = 'N'
                     BEGIN
      	               --Insert Transmitlog2
      	               SELECT @b_success = 1
                        
                        EXECUTE nspg_getkey      
                              'TransmitLogKey2'      
                              , 10      
                              , @c_TransmitLogKey OUTPUT      
                              , @b_success        OUTPUT      
                              , @n_err            OUTPUT      
                              , @c_errmsg         OUTPUT      
                        
                        IF NOT @b_success = 1      
                        BEGIN      
                           SET @n_continue = 3      
                           SET @n_err = 71810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
                           SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispVoicePick02)' + 
                                           ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
                           GOTO QUIT_SP  
                        END 
                        
                        INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key2, key3, transmitflag)
                        SELECT @c_TransmitLogKey, 'WSPICKVCLOG', @c_Pickslipno, @c_Orderkey, @c_Storerkey, '0'
                        
                        SELECT @n_err = @@ERROR  
                        
                        IF @n_err <> 0  
                        BEGIN
                           SELECT @n_continue = 3  
                           SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=71815    
                           SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                                            + ': Insert Failed On Table TRANSMITLOG2. (ispVoicePick02)'   
                                            + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
                        END 
                     END

                     IF ISNULL(@c_Orderkey,'') = ''   --Conso
                     BEGIN
                        SET @c_SQL = N'UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                  	                  SET TrafficCop =  NULL ' + @c_UpdateString + '
                  	                  WHERE Loadkey = @c_Loadkey'

                        SET @c_SQLParm =  N'@c_Loadkey    NVARCHAR(10) '

                        EXEC sp_ExecuteSQL @c_SQL
                                         , @c_SQLParm
                                         , @c_Loadkey
                     END
                     ELSE
                     BEGIN
                  	   SET @c_SQL = N'UPDATE LOADPLANDETAIL WITH (ROWLOCK)
                  	                  SET TrafficCop =  NULL ' + @c_UpdateString + '
                  	                  WHERE OrderKey = @c_Orderkey'

                        SET @c_SQLParm =  N'@c_Orderkey    NVARCHAR(10) '

                        EXEC sp_ExecuteSQL @c_SQL
                                         , @c_SQLParm
                                         , @c_Orderkey
                     END
                     
                  	
                  	FETCH NEXT FROM cur_Orderkey INTO @c_Orderkey
                  END
                  CLOSE cur_Orderkey
                  DEALLOCATE cur_Orderkey 
                  
      	      END
            END
NEXT_PSNO:
            FETCH NEXT FROM cur_Pickheaderkey INTO @c_Pickslipno
         END
         CLOSE cur_Pickheaderkey
         DEALLOCATE cur_Pickheaderkey
         
         SET @c_SQL = N'SELECT @n_ResultRowCnt = COUNT(1) 
            	         FROM LOADPLANDETAIL LPD (NOLOCK) 
            	         WHERE LPD.Loadkey = @c_Loadkey ' + @c_FilterString2
         
         SET @c_SQLParm =  N'@c_Loadkey       NVARCHAR(10)
                           , @n_ResultRowCnt  INT           OUTPUT '
         
         EXEC sp_ExecuteSQL @c_SQL
                          , @c_SQLParm
                          , @c_Loadkey
                          , @n_ResultRowCnt   OUTPUT
         
         IF @n_ResultRowCnt = 0
         BEGIN
            SET @c_SQL = N'UPDATE LoadPlan WITH (ROWLOCK)
                     	   SET TrafficCop =  NULL ' + @c_UpdateCFMString + '
                     	   WHERE LoadKey = @c_Loadkey'
            
            SET @c_SQLParm =  N'@c_Loadkey    NVARCHAR(10) '

            EXEC sp_ExecuteSQL @c_SQL
                             , @c_SQLParm
                             , @c_Loadkey
         END
         
NEXT_LOAD:
         FETCH NEXT FROM cur_Loadkey INTO @c_Loadkey, @c_Facility
      END
   END

   IF @b_Debug = 1
   BEGIN 
      SELECT * FROM #TMP_DATA
   END

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_DATA') IS NOT NULL
      DROP TABLE #TMP_DATA
      
   IF CURSOR_STATUS('GLOBAL', 'cur_Loadkey') IN (0 , 1)
   BEGIN
      CLOSE cur_Loadkey
      DEALLOCATE cur_Loadkey   
   END
   
   IF CURSOR_STATUS('LOCAL', 'cur_Pickheaderkey') IN (0 , 1)
   BEGIN
      CLOSE cur_Pickheaderkey
      DEALLOCATE cur_Pickheaderkey   
   END
   
   IF CURSOR_STATUS('LOCAL', 'cur_Orderkey') IN (0 , 1)
   BEGIN
      CLOSE cur_Orderkey
      DEALLOCATE cur_Orderkey   
   END

   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispVoicePick02'
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