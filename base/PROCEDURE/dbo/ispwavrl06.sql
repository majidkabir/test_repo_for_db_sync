SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* SP: ispWAVRL06                                                       */
/* Creation Date: 15-SEP-2021                                           */
/* Copyright: LFL                                                       */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-17958 - [CN] MAST VS Add New RCM & SP for Auto-Sorting  */ 
/*          Machines Trigger                                            */
/*                                                                      */
/* Usage:   Storerconfig WaveReleaseToWCS_SP={SPName} to enable release */
/*          Wave to WCS option                                          */
/*                                                                      */
/* Called By: isp_WaveReleaseToWCS_Wrapper                              */
/*                                                                      */
/* GitLab Version: 1.2                                                  */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author   Ver  Purposes                                  */
/* 15-Sep-2021  WLChooi  1.0  DevOps Combine Script                     */
/* 10-Jan-2022  WLChooi  1.1  WMS-17958 - Block insert transmitlog2 if  */
/*                            previous record is added less than 1 min  */
/*                            (WL01)                                    */
/* 21-Jan-2022  WLChooi  1.2  WMS-18802 - Configure Key1, Key2 & Key3 in*/
/*                            Storerconfig.Option5 (WL02)               */
/************************************************************************/

CREATE PROC [dbo].[ispWAVRL06] 
   @c_WaveKey  NVARCHAR(10),
   @b_Success  INT OUTPUT,
   @n_err      INT OUTPUT,
   @c_errmsg   NVARCHAR(250) OUTPUT
AS
BEGIN
   SET NOCOUNT ON
   SET QUOTED_IDENTIFIER OFF
   SET ANSI_NULLS OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue       INT
         , @b_debug          INT
         , @n_StartTranCnt   INT
         , @c_Storerkey      NVARCHAR(15)
         , @c_TableName      NVARCHAR(15)
         , @c_Loadkey        NVARCHAR(10)
         , @c_Orderkey       NVARCHAR(10)
         , @c_PickslipNo     NVARCHAR(10)
         , @c_Facility       NVARCHAR(5)
         , @c_OrderStatus    NVARCHAR(1)
         , @c_DocType        NVARCHAR(1)
         , @c_trmlogkey      NVARCHAR(10)
         , @c_TransmitBatch  NVARCHAR(50) = ''
         , @dt_TLDateTime    DATETIME   --WL01

   IF @n_err = 1
      SET @b_debug = 1

   --WL02 S
   DECLARE @c_GetStorerkey          NVARCHAR(15)
         , @c_SQL                   NVARCHAR(4000)          
         , @c_ExecStatements        NVARCHAR(4000)      
         , @c_ExecArguments         NVARCHAR(4000)
         , @c_Authority             NVARCHAR(50)
         , @c_Option1               NVARCHAR(50)
         , @c_Option2               NVARCHAR(50)
         , @c_Option3               NVARCHAR(50)
         , @c_Option4               NVARCHAR(50)
         , @c_Option5               NVARCHAR(4000)
         , @c_B2BSelectStatement    NVARCHAR(4000)
         , @c_B2CSelectStatement    NVARCHAR(4000)
         , @c_Configkey             NVARCHAR(100) = 'WaveReleaseToWCS_SP'

   SELECT @c_GetStorerkey = OH.Storerkey
   FROM ORDERS OH (NOLOCK)
   WHERE OH.UserDefine09 = @c_WaveKey

   EXECUTE nspGetRight                                
      @c_Facility  = @c_Facility,                     
      @c_StorerKey = @c_GetStorerkey,                    
      @c_Sku       = '',
      @c_ConfigKey = @c_Configkey,
      @b_Success   = @b_Success   OUTPUT,             
      @c_authority = @c_Authority OUTPUT,             
      @n_err       = @n_err       OUTPUT,             
      @c_errmsg    = @c_errmsg    OUTPUT,             
      @c_Option1   = @c_Option1   OUTPUT,               
      @c_Option2   = @c_Option2   OUTPUT,               
      @c_Option3   = @c_Option3   OUTPUT,               
      @c_Option4   = @c_Option4   OUTPUT,               
      @c_Option5   = @c_Option5   OUTPUT 

   IF ISNULL(@c_B2BSelectStatement,'') = ''
      SELECT @c_B2BSelectStatement = dbo.fnc_GetParamValueFromString('@c_B2BSelectStatement', @c_Option5, @c_B2BSelectStatement) 

   IF ISNULL(@c_B2CSelectStatement,'') = ''
      SELECT @c_B2CSelectStatement = dbo.fnc_GetParamValueFromString('@c_B2CSelectStatement', @c_Option5, @c_B2CSelectStatement) 
   
   IF ISNULL(@c_B2BSelectStatement,'') = ''
      SET @c_B2BSelectStatement = ' ORDERS.Storerkey, ORDERS.Loadkey, PICKHEADER.PickHeaderkey '

   IF ISNULL(@c_B2CSelectStatement,'') = ''
      SET @c_B2CSelectStatement = ' ORDERS.Storerkey, ORDERS.Loadkey, PICKDETAIL.PickSlipNo '
   --WL02 E
      
   SELECT @n_StartTranCnt = @@TRANCOUNT, @n_continue = 1, @b_success = 1, @n_err = 0, @c_errmsg = ''

   -----Get Wave Info-----
   IF @n_continue = 1 OR @n_continue = 2
   BEGIN      
       SELECT @c_OrderStatus = MIN(ORDERS.[STATUS])
            , @c_DocType     = MIN(ORDERS.Doctype)
       FROM WAVE (NOLOCK)
       JOIN WAVEDETAIL (NOLOCK) ON WAVE.Wavekey = WAVEDETAIL.WaveKey
       JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey        
       WHERE WAVE.Wavekey = @c_Wavekey                  
   END
  
   ------Validation--------
   IF @n_continue=1 or @n_continue=2  
   BEGIN          
      IF @c_OrderStatus < '1'
      BEGIN
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68025   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
         SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Release Failed. Some of the orders are not fully allocated. (ispWAVRL06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '           
         GOTO RETURN_SP
      END                                   
   END

   ------Insert Into Transmitlog2-------   
   IF (@n_continue = 1 OR @n_continue = 2)
   BEGIN
      IF @c_DocType = 'N'
      BEGIN
         SET @c_TableName = 'WSRCSWVB2B'

         --WL02 S
         --DECLARE cur_WAVEORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         --SELECT DISTINCT OH.Storerkey, OH.Loadkey, PH.PickHeaderkey
         --FROM WAVEDETAIL WD (NOLOCK)
         --JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         --JOIN PICKHEADER PH (NOLOCK) ON OH.Orderkey = PH.Orderkey
         --JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'WSRCSWVCON' AND CL.Short = '1'
         --                         AND CL.Long  = OH.Facility
         --                         AND CL.UDF01 = OH.DocType
         --                         AND CL.UDF02 = ISNULL(OH.ECOM_SINGLE_Flag,'')
         --                         AND CL.UDF03 = OH.[Status]
         --WHERE WD.Wavekey = @c_Wavekey
         --UNION ALL
         --SELECT DISTINCT OH.Storerkey, OH.Loadkey, PH.PickHeaderkey
         --FROM WAVEDETAIL WD (NOLOCK)
         --JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         --JOIN LOADPLANDETAIL LPD (NOLOCK) ON LPD.OrderKey = WD.OrderKey
         --JOIN PICKHEADER PH (NOLOCK) ON LPD.LoadKey = PH.ExternOrderKey
         --JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'WSRCSWVCON' AND CL.Short = '1'
         --                         AND CL.Long  = OH.Facility
         --                         AND CL.UDF01 = OH.DocType
         --                         AND CL.UDF02 = ISNULL(OH.ECOM_SINGLE_Flag,'')
         --                         AND CL.UDF03 = OH.[Status]
         --WHERE WD.Wavekey = @c_Wavekey

         SET @c_SQL = ' DECLARE cur_WAVEORDER CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)
                    + ' SELECT DISTINCT ' + @c_B2BSelectStatement + CHAR(13)
                    + ' FROM WAVEDETAIL (NOLOCK) ' + CHAR(13)
                    + ' JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey ' + CHAR(13)
                    + ' JOIN PICKHEADER (NOLOCK) ON ORDERS.Orderkey = PICKHEADER.Orderkey ' + CHAR(13)
                    + ' JOIN CODELKUP (NOLOCK) ON CODELKUP.LISTNAME = ''WSRCSWVCON'' AND CODELKUP.Short = ''1'' ' + CHAR(13)
                    + '                       AND CODELKUP.Long  = ORDERS.Facility ' + CHAR(13)
                    + '                       AND CODELKUP.UDF01 = ORDERS.DocType ' + CHAR(13)
                    + '                       AND CODELKUP.UDF02 = ISNULL(ORDERS.ECOM_SINGLE_Flag,'''') ' + CHAR(13)
                    + '                       AND CODELKUP.UDF03 = ORDERS.[Status] ' + CHAR(13)
                    + ' WHERE WAVEDETAIL.Wavekey = @c_Wavekey ' + CHAR(13)
                    + ' UNION ALL ' + CHAR(13)
                    + ' SELECT DISTINCT ' + @c_B2BSelectStatement + CHAR(13)
                    + ' FROM WAVEDETAIL (NOLOCK) ' + CHAR(13)
                    + ' JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey ' + CHAR(13)
                    + ' JOIN LOADPLANDETAIL (NOLOCK) ON LOADPLANDETAIL.OrderKey = WAVEDETAIL.OrderKey ' + CHAR(13)
                    + ' JOIN PICKHEADER (NOLOCK) ON LOADPLANDETAIL.LoadKey = PICKHEADER.ExternOrderKey ' + CHAR(13)
                    + ' JOIN CODELKUP (NOLOCK) ON CODELKUP.LISTNAME = ''WSRCSWVCON'' AND CODELKUP.Short = ''1'' ' + CHAR(13)
                    + '                       AND CODELKUP.Long  = ORDERS.Facility ' + CHAR(13)
                    + '                       AND CODELKUP.UDF01 = ORDERS.DocType ' + CHAR(13)
                    + '                       AND CODELKUP.UDF02 = ISNULL(ORDERS.ECOM_SINGLE_Flag,'''') ' + CHAR(13)
                    + '                       AND CODELKUP.UDF03 = ORDERS.[Status] ' + CHAR(13)
                    + ' WHERE WAVEDETAIL.Wavekey = @c_Wavekey '

         SET @c_ExecArguments = N'  @c_Wavekey            NVARCHAR(10) '

         EXEC sp_ExecuteSql  @c_SQL  
                           , @c_ExecArguments   
                           , @c_Wavekey
         --WL02 E
      END
      ELSE IF @c_DocType = 'E'
      BEGIN
         SET @c_TableName = 'WSRCSWVB2C'

         --WL02 S
         --DECLARE cur_WAVEORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         --SELECT DISTINCT OH.Storerkey, OH.Loadkey, PD.PickSlipNo
         --FROM WAVEDETAIL WD (NOLOCK)
         --JOIN ORDERS OH (NOLOCK) ON WD.Orderkey = OH.Orderkey
         --JOIN PICKDETAIL PD (NOLOCK) ON OH.Orderkey = PD.Orderkey
         --JOIN CODELKUP CL (NOLOCK) ON CL.LISTNAME = 'WSRCSWVCON' AND CL.Short = '1'
         --                         AND CL.Long  = OH.Facility
         --                         AND CL.UDF01 = OH.DocType
         --                         AND CL.UDF02 = ISNULL(OH.ECOM_SINGLE_Flag,'')
         --                         AND CL.UDF03 = OH.[Status]
         --WHERE WD.Wavekey = @c_Wavekey

         SET @c_SQL = ' DECLARE cur_WAVEORDER CURSOR FAST_FORWARD READ_ONLY FOR ' + CHAR(13)  
                    + ' SELECT DISTINCT ' + @c_B2CSelectStatement + CHAR(13)
                    + ' FROM WAVEDETAIL (NOLOCK) ' + CHAR(13)
                    + ' JOIN ORDERS (NOLOCK) ON WAVEDETAIL.Orderkey = ORDERS.Orderkey ' + CHAR(13)
                    + ' JOIN PICKDETAIL (NOLOCK) ON ORDERS.Orderkey = PICKDETAIL.Orderkey ' + CHAR(13)
                    + ' JOIN CODELKUP (NOLOCK) ON CODELKUP.LISTNAME = ''WSRCSWVCON'' AND CODELKUP.Short = ''1'' ' + CHAR(13)
                    + '                       AND CODELKUP.Long  = ORDERS.Facility ' + CHAR(13)
                    + '                       AND CODELKUP.UDF01 = ORDERS.DocType ' + CHAR(13)
                    + '                       AND CODELKUP.UDF02 = ISNULL(ORDERS.ECOM_SINGLE_Flag,'''') ' + CHAR(13)
                    + '                       AND CODELKUP.UDF03 = ORDERS.[Status] ' + CHAR(13)
                    + ' WHERE WAVEDETAIL.Wavekey = @c_Wavekey ' + CHAR(13)

         SET @c_ExecArguments = N'  @c_Wavekey            NVARCHAR(10) '

         EXEC sp_ExecuteSql  @c_SQL  
                           , @c_ExecArguments   
                           , @c_Wavekey
         --WL02 E
      END
      ELSE
      BEGIN
         GOTO RETURN_SP 
      END
      PRINT @c_SQL
      OPEN cur_WAVEORDER  
      FETCH NEXT FROM cur_WAVEORDER INTO @c_Storerkey, @c_Loadkey, @c_Pickslipno      
      
      WHILE @@FETCH_STATUS = 0 AND @n_continue IN(1,2) 
      BEGIN  
         SELECT @b_success = 1

         --WL01 S
         SELECT @dt_TLDateTime = TL2.AddDate 
         FROM TRANSMITLOG2 TL2 (NOLOCK)
         WHERE TL2.tablename = @c_TableName
         AND TL2.key1 = @c_PickslipNo
         AND TL2.key2 = @c_Loadkey
         AND TL2.key3 = @c_Storerkey

         IF ISNULL(@dt_TLDateTime,'1900-01-01') <> '1900-01-01'
         BEGIN
            IF DATEDIFF(SECOND, @dt_TLDateTime, GETDATE()) <= 60
            BEGIN
               GOTO NEXT_LOOP   --Block insert if less than 60 seconds
            END
         END
         --WL01 E

         IF (@n_continue = 1 OR @n_continue = 2)
         BEGIN
            SELECT @b_success = 1
            EXECUTE nspg_getkey
            'TransmitlogKey2'
            , 10
            , @c_trmlogkey OUTPUT
            , @b_success   OUTPUT
            , @n_err       OUTPUT
            , @c_errmsg    OUTPUT
         
            IF NOT @b_success = 1
            BEGIN
               SELECT @n_continue = 3
               SELECT @c_errmsg = CONVERT(CHAR(250),@n_err), @n_err = 68030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.
               SELECT @c_errmsg = 'NSQL' + CONVERT(char(5),@n_err) 
                                + ': Unable to Obtain transmitlogkey. (ispWAVRL06) ( SQLSvr MESSAGE=' 
                                + dbo.fnc_LTrim(dbo.fnc_RTrim(@c_errmsg)) + ' ) '
               GOTO RETURN_SP 
            END
            ELSE 
            BEGIN
               IF (@n_continue = 1 OR @n_continue = 2)
               BEGIN
                  INSERT INTO Transmitlog2 (transmitlogkey, tablename, key1, key2, key3, transmitflag, TransmitBatch)
                  VALUES (@c_trmlogkey, @c_TableName, @c_Pickslipno, @c_Loadkey, @c_Storerkey, '0', @c_TransmitBatch)

                  SELECT @n_err = @@ERROR

                  IF @n_err <> 0
                  BEGIN
                     SELECT @n_continue = 3  
                     SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68035   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
                     SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into TRANSMITLOG2 Failed. (ispWAVRL06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
                     GOTO RETURN_SP 
                  END
               END
            END
         END   
                 
         /*EXEC ispGenTransmitLog2 @c_TableName, @c_Pickslipno, @c_Loadkey, @c_StorerKey, ''    
            , @b_success OUTPUT    
            , @n_err OUTPUT    
            , @c_errmsg OUTPUT
         
         IF @b_success <> 1    
         BEGIN
            SELECT @n_continue = 3  
            SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68030   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
            SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': Insert into TRANSMITLOG2 Failed. (ispWAVRL06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
            GOTO RETURN_SP 
         END */
         
         UPDATE dbo.LoadPlan
         SET UserDefine05 = 'Minions'
         WHERE LoadKey = @c_Loadkey

         IF @@ERROR <> 0 
         BEGIN
             SELECT @n_continue = 3  
             SELECT @c_errmsg = CONVERT(NVARCHAR(250),@n_err), @n_err = 68040   -- Should Be Set To The SQL Errmessage but I don't know how to do so.  
             SELECT @c_errmsg='NSQL'+CONVERT(NVARCHAR(5),@n_err)+': UPDATE Loadplan Failed. (ispWAVRL06)' + ' ( ' + ' SQLSvr MESSAGE=' + RTRIM(@c_errmsg) + ' ) '  
             GOTO RETURN_SP 
         END  
         NEXT_LOOP:   --WL01
         FETCH NEXT FROM cur_WAVEORDER INTO @c_Storerkey, @c_Loadkey, @c_Pickslipno    
      END
      CLOSE cur_WAVEORDER  
      DEALLOCATE cur_WAVEORDER                                   
   END  

RETURN_SP:
   IF ISNULL(@c_errmsg,'') = ''
      SET @c_errmsg = 'Auto-Sorting API record generated successfully.'

   IF (SELECT CURSOR_STATUS('GLOBAL','cur_WAVEORDER')) >=0   --WL02 
   BEGIN
      CLOSE cur_WAVEORDER           
      DEALLOCATE cur_WAVEORDER      
   END  

   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SELECT @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_StartTranCnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'ispWAVRL06'
      --RAISERROR @n_err @c_errmsg
      RETURN
   END
   ELSE
   BEGIN
      SELECT @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTranCnt
      BEGIN
         COMMIT TRAN
      END
      RETURN
   END
END

GO