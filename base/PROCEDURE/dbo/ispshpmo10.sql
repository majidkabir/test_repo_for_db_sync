SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***************************************************************************/
/* Stored Procedure: ispSHPMO10                                            */
/* Creation Date: 27-Jul-2022                                              */
/* Copyright: LFL                                                          */
/* Written by:  CHONGCS                                                    */
/*                                                                         */
/* Purpose: WMS-20314 -CN_Nike_SEC_BaoZun_WCI_Interface_                   */
/*          Generate_Transmitlog2                                          */
/*                                                                         */
/* Called By: ispPostMBOLShipWrapper                                       */
/*                                                                         */
/*                                                                         */
/* GitLab Version: 1.0                                                     */
/*                                                                         */
/* Version: 5.4                                                            */
/*                                                                         */
/* Data Modifications:                                                     */
/*                                                                         */
/* Updates:                                                                */
/* Date         Author  Ver   Purposes                                     */
/* 27-JUL-2022  CHONGCS 1.0   DevOps Combine Script                        */
/***************************************************************************/  
CREATE PROC [dbo].[ispSHPMO10]  
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
         Conso       NVARCHAR(1)  NULL 
      )
      
      --Discrete
      INSERT INTO #TMP_DATA (Loadkey, Orderkey, Storerkey, Pickslipno, Conso) 
      SELECT DISTINCT '', MD.Orderkey, PH.Storerkey, PH.Pickslipno, 'N'  
      FROM  MBOL MB (NOLOCK)
      JOIN  MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MB.MbolKey
      JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
      JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
      WHERE MD.MBOLKey = @c_MBOLkey 
      --AND MB.Status='9'
      UNION ALL
      SELECT DISTINCT LPD.LoadKey, '', PH.Storerkey, PH.Pickslipno, 'Y'  --Conso 
      FROM  MBOL MB (NOLOCK)
      JOIN  MBOLDETAIL MD (NOLOCK) ON MD.MbolKey = MB.MbolKey
      JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.Orderkey = MD.OrderKey
      JOIN PACKHEADER PH (NOLOCK) ON PH.Loadkey = LPD.Loadkey  
      WHERE MD.MBOLKey = @c_MBOLkey AND (PH.OrderKey = '' OR PH.OrderKey IS NULL)
      --AND MB.Status='9'

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
         FROM #TMP_DATA 
         WHERE Conso = 'N'
         ORDER BY Orderkey
  
      OPEN CUR_PACK  
  
      FETCH NEXT FROM CUR_PACK INTO @c_Orderkey, @c_Storerkey, @c_Pickslipno 
  
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
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispSHPMO10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END    

        
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key3, transmitflag)  
         SELECT @c_TransmitLogKey, 'WSSOISCFMLOG', @c_Pickslipno, @c_Storerkey, '0'    


    SET @c_TransmitLogKey = ''

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
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispSHPMO10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END  
      
         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key3, transmitflag)
         SELECT @c_TransmitLogKey, 'WSMBOLLOG', @c_Pickslipno, @c_Storerkey, '0'
         
         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72805    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Insert Failed On Table TRANSMITLOG2. (ispSHPMO10)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END 
         
         FETCH NEXT FROM CUR_PACK INTO @c_Orderkey, @c_Storerkey, @c_Pickslipno
      END
   END
   
   --Conso Cursor
   IF (@n_continue = 1 OR @n_continue = 2) 
   BEGIN
      DECLARE CUR_PACKConso CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT LoadKey, Storerkey , Pickslipno
         FROM #TMP_DATA 
         WHERE Conso = 'Y'
         ORDER BY Loadkey
  
      OPEN CUR_PACKConso  
  
      FETCH NEXT FROM CUR_PACKConso INTO @c_Loadkey, @c_Storerkey, @c_Pickslipno  
  
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
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispSHPMO10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END 

         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key3, transmitflag)  
         SELECT @c_TransmitLogKey, 'WSSOISCFMLOG', @c_Pickslipno, @c_Storerkey, '0' 


           SET @c_TransmitLogKey = ''

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
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Unable to Obtain TransmitLogKey2. (ispSHPMO10)' + ' ( ' + ' SQLSvr MESSAGE=' + LTRIM(RTRIM(@c_errmsg)) + ' ) '      
            GOTO QUIT_SP  
         END  

         INSERT INTO TRANSMITLOG2 (transmitlogkey, tablename, key1, key3, transmitflag)
         SELECT @c_TransmitLogKey, 'WSMBOLLOG', @c_Pickslipno, @c_Storerkey, '0'
         
         SELECT @n_err = @@ERROR  
         
         IF @n_err <> 0  
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err=72815    
            SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),ISNULL(@n_err,0))   
                             + ': Insert Failed On Table TRANSMITLOG2. (ispSHPMO10)'   
                             + ' ( SQLSvr MESSAGE=' + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '  
         END 
         
         FETCH NEXT FROM CUR_PACKConso INTO @c_Loadkey, @c_Storerkey, @c_Pickslipno  
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
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispSHPMO10'
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