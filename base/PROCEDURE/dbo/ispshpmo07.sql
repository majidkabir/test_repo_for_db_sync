SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO07                                            */
/* Creation Date: 21-Jan-2021                                              */
/* Copyright: LFL                                                          */
/* Written by:  WLChooi                                                    */
/*                                                                         */
/* Purpose: WMS-16085 - [RG] CN_Nike_SEC_Normal_Goods_Issue_Interface_     */
/*          Generate_Transmitlog2 Log                                      */
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
/*                                                                         */
/*                                                                         */
/* GitLab Version: 1.1                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 21-Jan-2021  WLChooi 1.0   DevOps Combine Script                        */
/* 20-Oct-2022  WLChooi 1.1   WMS-21029 - Insert TL2 by Option5 (WL01)     */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO07]  
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
  
   DECLARE @b_Debug              INT
         , @n_Continue           INT 
         , @n_StartTCnt          INT 

   DECLARE @c_Loadkey         NVARCHAR(10)
         , @c_Orderkey        NVARCHAR(10)
         , @c_Pickslipno      NVARCHAR(10)
         , @c_TransmitLogKey  NVARCHAR(10)

   --WL01 S
   DECLARE @c_Key2            NVARCHAR(100)
         , @c_SQL             NVARCHAR(MAX)
         , @c_ExecArguments   NVARCHAR(MAX)
         , @c_Facility        NVARCHAR(5) 
         , @c_SValue          NVARCHAR(50)
         , @c_Option1         NVARCHAR(50) = ''
         , @c_Option2         NVARCHAR(50) = ''
         , @c_Option3         NVARCHAR(50) = ''
         , @c_Option4         NVARCHAR(50) = ''
         , @c_Option5         NVARCHAR(4000) = ''

   IF ISNULL(@c_Storerkey,'') = ''
   BEGIN
      SELECT TOP 1 @c_Storerkey = OH.Storerkey
      FROM ORDERS OH (NOLOCK)
      WHERE OH.MBOLKey = @c_MBOLkey
   END

   EXEC nspGetRight  
      @c_Facility          -- facility  
   ,  @c_Storerkey         -- Storerkey  
   ,  NULL                 -- Sku  
   ,  'PostMBOLShipSP' -- Configkey  
   ,  @b_Success                 OUTPUT   
   ,  @c_SValue                  OUTPUT   
   ,  @n_Err                     OUTPUT   
   ,  @c_ErrMsg                  OUTPUT 
   ,  @c_Option1                 OUTPUT
   ,  @c_Option2                 OUTPUT
   ,  @c_Option3                 OUTPUT
   ,  @c_Option4                 OUTPUT
   ,  @c_Option5                 OUTPUT

   IF @b_success <> 1  
   BEGIN  
      SET @n_continue = 3  
      SET @n_err = 72790   
      SET @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Error Executing nspGetRight. (ispSHPMO07)'   
                  + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '   
      GOTO QUIT_SP  
   END 

   SELECT @c_Key2 = dbo.fnc_GetParamValueFromString('@c_Key2', @c_Option5, '') 
   --WL01 E

   SET @b_Success= 1 
   SET @n_Err    = 0  
   SET @c_ErrMsg = ''
   SET @b_Debug = '0' 
   SET @n_Continue = 1  
   SET @n_StartTCnt = @@TRANCOUNT  

   --Prepare Data, check Discrete or Conso
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN   
      CREATE TABLE #TMP_DATA (
         Loadkey     NVARCHAR(10) NULL,
         Orderkey    NVARCHAR(10) NULL,
         Storerkey   NVARCHAR(15) NULL,
         Pickslipno  NVARCHAR(10) NULL,
         Conso       NVARCHAR(1)  NULL,
         Key2        NVARCHAR(100)  NULL --WL01
      )

      --WL01 S
      --Discrete
      SET @c_SQL = N' INSERT INTO #TMP_DATA (Loadkey, Orderkey, Storerkey, Pickslipno, Conso ' + CHAR(13)
                 + N'                      , Key2) ' + CHAR(13)
                 + N' SELECT DISTINCT '''', MBOLDETAIL.Orderkey, PACKHEADER.Storerkey, PACKHEADER.Pickslipno, ''N'' ' + CHAR(13)  
                 + CASE WHEN ISNULL(@c_Key2,'') = '' THEN N' , '''' ' ELSE N' , ' + @c_Key2 END + CHAR(13)
                 + N' FROM MBOLDETAIL (NOLOCK) ' + CHAR(13)
                 + N' JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey ' + CHAR(13)  
                 + N' JOIN PACKHEADER (NOLOCK) ON MBOLDETAIL.Orderkey = PACKHEADER.Orderkey ' + CHAR(13)  
                 + N' WHERE MBOLDETAIL.MBOLKey = @c_MBOLkey ' + CHAR(13) 
                 + N' UNION ALL ' + CHAR(13)
                 + N' SELECT DISTINCT LOADPLANDETAIL.LoadKey, '''', PACKHEADER.Storerkey, PACKHEADER.Pickslipno, ''Y'' ' + CHAR(13)  --Conso
                 + CASE WHEN ISNULL(@c_Key2,'') = '' THEN N' , '''' ' ELSE N' , ' + @c_Key2 END + CHAR(13)
                 + N' FROM MBOLDETAIL (NOLOCK) ' + CHAR(13)
                 + N' JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.Orderkey = MBOLDETAIL.OrderKey ' + CHAR(13)
                 + N' JOIN PACKHEADER (NOLOCK) ON PACKHEADER.Loadkey = LOADPLANDETAIL.Loadkey ' + CHAR(13)  
                 + N' JOIN ORDERS (NOLOCK) ON MBOLDETAIL.Orderkey = ORDERS.Orderkey ' + CHAR(13)  
                 + N' WHERE MBOLDETAIL.MBOLKey = @c_MBOLkey AND (PACKHEADER.OrderKey = '''' OR PACKHEADER.OrderKey IS NULL) '

      SET @c_ExecArguments = N'  @c_MBOLkey  NVARCHAR(10)'

      EXEC sp_ExecuteSql   @c_SQL     
                         , @c_ExecArguments    
                         , @c_MBOLkey
      --WL01 E

      IF NOT EXISTS (SELECT 1 FROM #TMP_DATA)
      BEGIN
         GOTO QUIT_SP 
      END 
   END

   --Discrete Cursor
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      DECLARE CUR_PACK CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT Orderkey, Storerkey, Pickslipno
              , Key2 --WL01   
         FROM #TMP_DATA 
         WHERE Conso = 'N'
         ORDER BY Orderkey
  
      OPEN CUR_PACK  
  
      FETCH NEXT FROM CUR_PACK INTO @c_Orderkey, @c_Storerkey, @c_Pickslipno 
                                  , @c_Key2  --WL01
  
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
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
            SET @n_err = 72800   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispSHPMO07)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END      
      
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key3, transmitflag, key2)   --WL01
         SELECT @c_TransmitLogKey, 'WSSOISCFMLOG', @c_Pickslipno, @c_Storerkey, '0', @c_Key2    --WL01
         
         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72805    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Insert Failed On Table TRANSMITLOG2. (ispSHPMO07)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END 
         
         FETCH NEXT FROM CUR_PACK INTO @c_Orderkey, @c_Storerkey, @c_Pickslipno
                                     , @c_Key2  --WL01
      END
   END
   
   --Conso Cursor
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      DECLARE CUR_PACKConso CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LoadKey, Storerkey , Pickslipno
              , Key2   --WL01   
         FROM #TMP_DATA 
         WHERE Conso = 'Y'
         ORDER BY Loadkey
  
      OPEN CUR_PACKConso  
  
      FETCH NEXT FROM CUR_PACKConso INTO @c_Loadkey, @c_Storerkey, @c_Pickslipno  
                                       , @c_Key2  --WL01
  
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2)  
      BEGIN  
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
            SET @n_err = 72810   -- Should Be Set To The SQL Errmessage but I don't know how to do so.      
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispSHPMO07)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END 

         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key3, transmitflag, key2)   --WL01
         SELECT @c_TransmitLogKey, 'WSSOISCFMLOG', @c_Pickslipno, @c_Storerkey, '0', @c_Key2    --WL01
         
         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72815    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Insert Failed On Table TRANSMITLOG2. (ispSHPMO07)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END 
         
         FETCH NEXT FROM CUR_PACKConso INTO @c_Loadkey, @c_Storerkey, @c_Pickslipno  
                                          , @c_Key2  --WL01
      END
   END

QUIT_SP:
   IF OBJECT_ID('tempdb..#TMP_DATA') IS NOT NULL
      DROP TABLE #TMP_DATA
      
   IF CURSOR_STATUS('LOCAL', 'CUR_PACK') IN (0 , 1)
   BEGIN
      CLOSE CUR_PACK
      DEALLOCATE CUR_PACK   
   END
   
   IF CURSOR_STATUS('LOCAL', 'CUR_PACKConso') IN (0 , 1)
   BEGIN
      CLOSE CUR_PACKConso
      DEALLOCATE CUR_PACKConso   
   END
      
   IF @n_continue = 3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0

      IF @@TRANCOUNT = 1 AND @@TRANCOUNT >= @n_StartTCnt
      BEGIN
         ROLLBACK TRAN
      END
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO07'
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