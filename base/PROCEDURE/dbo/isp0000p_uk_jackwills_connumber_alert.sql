SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Store Procedure:  isp0000P_UK_JackWills_ConNumber_Alert              */
/* Creation Date: 11-Aug-2014                                           */
/* Copyright: IDS                                                       */
/* Written by: TKLIM                                                    */
/*                                                                      */
/* Purpose:  - SOS#318085 UK JACKWILLS TNT ConNumber Alert              */
/*                                                                      */
/* Input Parameters:  @c_Storerkey     - Storerkey                      */
/*                    @b_Debug         - 0                              */
/*                                                                      */
/* Output Parameters: @b_Success       - Success Flag  = 0              */
/*                    @n_Err           - Error Code    = 0              */
/*                    @c_ErrMsg        - Error Message = ''             */
/*                                                                      */
/*                                                                      */
/* Called By:  Scheduler job                                            */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author  Ver  Purposes                                   */
/* 02-Oct-2014  James   1.1  SOS322124 - Add Email footer (james01)     */
/* 07-Oct-2014  James   1.2  SOS321523 - Change to use UCCLabelNo from  */
/*                           cartonshipmentdetail (james02)             */
/* 17-Oct-2014  James   1.3  SOS323146 - Filter by email (james03)      */
/* 20-Oct-2014  James   1.4  Extend length of email body (james04)      */
/* 23-Oct-2014  James   1.5  Bug fix (james05)                          */
/************************************************************************/

CREATE PROC [dbo].[isp0000P_UK_JackWills_ConNumber_Alert] (
       @c_Storerkey     NVARCHAR(15)
     , @c_SourceDBName  NVARCHAR(20)
     , @b_Debug         INT         = 0
     , @b_Success       INT         = 0      OUTPUT
     , @n_Err           INT         = 0      OUTPUT
     , @c_ErrMsg        CHAR(250)   = NULL   OUTPUT
     )
AS 
BEGIN 
   SET NOCOUNT ON
   SET ANSI_DEFAULTS OFF  
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF  

   /*********************************************/
   /* Variables Declaration (Start)             */
   /*********************************************/
   DECLARE @n_Continue              INT
         , @n_StartTCnt             INT
         , @c_ExecStatements        NVARCHAR(4000)
         , @c_ExecArguments         NVARCHAR(4000)
         , @c_Language              NVARCHAR(5)

   DECLARE @c_TransmitLogKey        NVARCHAR(10)
         , @c_TableName             NVARCHAR(30)
         , @c_TxFlag0               NVARCHAR(1) 
         , @c_TxFlag1               NVARCHAR(1) 
         , @c_TxFlag9               NVARCHAR(1) 
         , @c_TxIgNor               NVARCHAR(10)   

   DECLARE @c_Body                  NVARCHAR(2000)  -- (james04)
         , @c_BodyHdr               NVARCHAR(200)
         , @c_Subject               NVARCHAR(200)
         , @c_Email                 NVARCHAR(60)
         , @c_TrackingNumber        NVARCHAR(30)
         , @c_Route                 NVARCHAR(10)
         , @c_BodyFooter            NVARCHAR(200)
         , @cNextLine               NVARCHAR(10)

   --SET @c_SourceDBName  = 'IDSUK_ET1'
   --SET @c_StorerKey     = 'JACKW'
   SET @c_Tablename     = 'MBOLLOG'
   SET @c_TxFlag0       = '0'
   SET @c_TxFlag1       = '1'
   SET @c_TxFlag9       = '9'
   SET @c_TxIgNor       = 'IGNOR'
   SET @c_Route         = 'TNT'
   SET @c_Subject       = 'Notification: Your Order is ready for dispatch ' 
   SET @c_BodyHdr       = 'Order is ready for dispatch, and your SackID is ' 
   SET @c_BodyFooter    = 'You Should Receive This Consignment Within 48 Hrs' 
   SET @cNextLine       = '<BR>'
   
   CREATE TABLE #TEMP(
      Email             NVARCHAR(60),
      TrackingNumber    NVARCHAR(30),
      TransmitLogKey    NVARCHAR(10)
   )

    --SET to IGNOR
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = '' 
   SET @c_ExecStatements = N'UPDATE '+ ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.TransmitLog3 WITH (ROWLOCK)'
                         + ' SET Transmitflag = @c_TxFlag1'
                         + ' FROM ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Transmitlog3 TL3 '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.MBOL MH WITH (NOLOCK) '
                         + ' ON MH.MBOLKey = TL3.Key1 '
                         + ' WHERE TL3.Tablename    = @c_Tablename ' 
                         + ' AND   TL3.Key3         = @c_StorerKey ' 
                         + ' AND   TL3.Transmitflag = @c_TxFlag0 ' 

   SET @c_ExecArguments = N'@c_Tablename        NVARCHAR(30)'
                        + ',@c_StorerKey        NVARCHAR(15)'
                        + ',@c_TxFlag0          NVARCHAR(1)'
                        + ',@c_TxFlag1          NVARCHAR(1)'

   BEGIN TRAN
   EXEC sp_ExecuteSql @c_ExecStatements 
                    , @c_ExecArguments 
                    , @c_Tablename
                    , @c_StorerKey
                    , @c_TxFlag0
                    , @c_TxFlag1

   IF @@ERROR = 0
   BEGIN 
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END
   ELSE
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68005
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))  
                       + ': Update records in TransmitLog3 fail. (isp0000P_UK_JackWills_ConNumber_Alert)' 
      GOTO QUIT        
   END 


   --SET to IGNOR when invalid
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = '' 
   SET @c_ExecStatements = N'UPDATE '+ ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.TransmitLog3 WITH (ROWLOCK)'
                         + ' SET Transmitflag = @c_TxIgNor'
                         + ' FROM ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Transmitlog3 TL3 '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.MBOL MH WITH (NOLOCK) '
                         + ' ON MH.MBOLKey = TL3.Key1 '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.MBOLDETAIL MD WITH (NOLOCK) '
                         + ' ON MD.MBOLKey = MH.MBOLKey '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.CartonShipmentDetail CSD WITH (NOLOCK) '
                         + ' ON CSD.OrderKey = MD.OrderKey '   -- join by orderkey because 1 load can split into 2 mbol(james05)
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Orders OH WITH (NOLOCK) '
                         + ' ON OH.OrderKey = CSD.OrderKey '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Storer ST WITH (NOLOCK) '
                         + ' ON ST.StorerKey = OH.ConsigneeKey '
                         + ' WHERE TL3.TableName    = @c_Tablename '
                         + ' AND   TL3.Key3         = @c_StorerKey ' 
                         + ' AND   TL3.Transmitflag = @c_TxFlag1 '
--                         + ' AND  (MH.PlaceOfLoadingQualifier <> @c_Route OR ST.Email1 = '''' OR CSD.TrackingNumber = '''') '
                         + ' AND  (MH.PlaceOfLoadingQualifier <> @c_Route OR ST.Email1 = '''' OR CSD.UCCLabelNo = '''') '  -- (james02)

   SET @c_ExecArguments = N'@c_Tablename        NVARCHAR(30)'
                        + ',@c_StorerKey        NVARCHAR(15)' 
                        + ',@c_TxIgNor          NVARCHAR(10)'
                        + ',@c_TxFlag1          NVARCHAR(1)' 
                        + ',@c_Route            NVARCHAR(10)' 

   BEGIN TRAN
   EXEC sp_ExecuteSql @c_ExecStatements 
                    , @c_ExecArguments 
                    , @c_Tablename 
                    , @c_StorerKey
                    , @c_TxIgNor
                    , @c_TxFlag1
                    , @c_Route

   IF @@ERROR = 0
   BEGIN 
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END
   ELSE
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68006
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))  
                       + ': Update records in TransmitLog3 fail. (isp0000P_UK_JackWills_ConNumber_Alert)' 
      GOTO QUIT                                                                               
   END 


   -- Retrieve related info from TransmitLog3 table into email
   SET @c_ExecStatements = N'INSERT INTO #TEMP (Email, TrackingNumber, TransmitLogKey) '
                         + ' SELECT '
                         + '   ISNULL(RTRIM(ST.Email1),'''') '
--                         + ' , ISNULL(RTRIM(CSD.TrackingNumber),'''') '
                         + ' , ISNULL(RTRIM(CSD.UCCLabelNo),'''') '     -- (james02)
                         + ' , ISNULL(RTRIM(TL3.TransmitLogKey),'''') '
                         + ' FROM ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Transmitlog3 TL3 WITH (NOLOCK) '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.MBOL MH WITH (NOLOCK) '
                         + ' ON MH.MBOLKey = TL3.Key1 '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.MBOLDETAIL MD WITH (NOLOCK) '
                         + ' ON MD.MBOLKey = MH.MBOLKey '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.CartonShipmentDetail CSD WITH (NOLOCK) '
                         + ' ON CSD.OrderKey = MD.OrderKey '-- join by orderkey because 1 load can split into 2 mbol(james05)
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Orders OH WITH (NOLOCK) '
                         + ' ON OH.OrderKey = CSD.OrderKey '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Storer ST WITH (NOLOCK) '
                         + ' ON ST.StorerKey = OH.ConsigneeKey '
                         + ' WHERE TL3.TableName    = @c_Tablename '
                         + ' AND   TL3.Key3         = @c_StorerKey ' 
                         + ' AND   TL3.Transmitflag = @c_TxFlag1 ' 
                         + ' AND   MH.PlaceOfLoadingQualifier = @c_Route '
                         + ' GROUP BY ISNULL(RTRIM(ST.Email1),'''') '
--                         + ' , ISNULL(RTRIM(CSD.TrackingNumber),'''') '  -- (james02)
                         + ' , ISNULL(RTRIM(CSD.UCCLabelNo),'''') '
                         + ' , ISNULL(RTRIM(TL3.TransmitLogKey),'''') '

   SET @c_ExecArguments = N'@c_Route            NVARCHAR(10)'
                        + ',@c_Tablename        NVARCHAR(30)'
                        + ',@c_StorerKey        NVARCHAR(15)' 
                        + ',@c_TxFlag1          NVARCHAR(1)' 

   IF @b_Debug = 1
   BEGIN
      SELECT @c_ExecStatements
   END

   BEGIN TRAN
   EXEC sp_ExecuteSql @c_ExecStatements 
                    , @c_ExecArguments  
                    , @c_Route
                    , @c_Tablename
                    , @c_StorerKey
                    , @c_TxFlag1

   IF @@ERROR = 0
   BEGIN 
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END
   ELSE
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68005
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))  
                       + ': Insert into #Temp fail. (isp0000P_UK_JackWills_ConNumber_Alert)' 
      GOTO QUIT        
   END



   IF EXISTS (SELECT 1 from #temp )
   BEGIN

      IF @b_Debug = 1
      BEGIN
         SELECT * FROM #TEMP
      END

      --Query Temp table to construct email.
      DECLARE C_EMAIL CURSOR FAST_FORWARD READ_ONLY FOR
      SELECT DISTINCT Email
      FROM #TEMP
      ORDER BY Email

      OPEN C_EMAIL
      FETCH NEXT FROM C_EMAIL INTO @c_Email

      WHILE @@FETCH_STATUS <> -1 
      BEGIN

         SET @c_Body = ''

         -- Loop Every TrackNumber for that email
         DECLARE C_TRACK CURSOR FAST_FORWARD READ_ONLY FOR
         SELECT DISTINCT TrackingNumber
         FROM #TEMP
         WHERE Email = @c_Email  -- (james03)
         ORDER BY TrackingNumber

         OPEN C_TRACK
         FETCH NEXT FROM C_TRACK INTO @c_TrackingNumber

         WHILE @@FETCH_STATUS <> -1 
         BEGIN
            
            SET @c_Body = @c_Body + '<BR> - ' + @c_TrackingNumber
         
            FETCH NEXT FROM C_TRACK INTO @c_TrackingNumber

         END
         CLOSE C_TRACK
         DEALLOCATE C_TRACK

         SET @c_Body = @c_BodyHdr + @c_Body + @cNextLine + @c_BodyFooter   -- (james01)

         IF @b_Debug = 1
         BEGIN
            SELECT @c_Email, @c_Subject, @c_Body
         END


         BEGIN TRAN
         EXEC msdb.dbo.sp_send_dbmail 
            @recipients = @c_Email,
            @subject = @c_Subject,
            @body = @c_Body,
            @body_format = 'HTML'    -- Either 'Text' or 'HTML'

         IF @@ERROR = 0
         BEGIN 
            WHILE @@TRANCOUNT > 0
               COMMIT TRAN
         END
         ELSE
         BEGIN
            SET @n_Continue = 3
            SET @n_Err = 68005
            SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))  
                             + ': Send email fail. (isp0000P_UK_JackWills_ConNumber_Alert)' 
            GOTO QUIT        
         END

         FETCH NEXT FROM C_EMAIL INTO @c_Email

      END
      CLOSE C_EMAIL
      DEALLOCATE C_EMAIL
   
      DROP TABLE #TEMP

   END

   --Update to '9'
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = '' 
   SET @c_ExecStatements = N'UPDATE '+ ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.TransmitLog3 WITH (ROWLOCK)'
                         + ' SET Transmitflag = @c_TxFlag9'
                         + ' FROM ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.Transmitlog3 TL3 '
                         + ' JOIN ' + ISNULL(RTRIM(@c_SourceDBName),'') + '.dbo.MBOL MH WITH (NOLOCK) '
                         + ' ON MH.MBOLKey = TL3.Key1 '
                         + ' WHERE TL3.Tablename    = @c_Tablename ' 
                         + ' AND   TL3.Key3         = @c_StorerKey ' 
                         + ' AND   TL3.Transmitflag = @c_TxFlag1 ' 

   SET @c_ExecArguments = N'@c_Tablename        NVARCHAR(30)'
                        + ',@c_StorerKey        NVARCHAR(15)'
                        + ',@c_TxFlag9          NVARCHAR(1)'
                        + ',@c_TxFlag1          NVARCHAR(1)'

   BEGIN TRAN
   EXEC sp_ExecuteSql @c_ExecStatements 
                    , @c_ExecArguments 
                    , @c_Tablename
                    , @c_StorerKey
                    , @c_TxFlag9
                    , @c_TxFlag1

   IF @@ERROR = 0
   BEGIN 
      WHILE @@TRANCOUNT > 0
         COMMIT TRAN
   END
   ELSE
   BEGIN
      SET @n_Continue = 3
      SET @n_Err = 68005
      SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))  
                       + ': Update records in TransmitLog3 fail. (isp0000P_UK_JackWills_ConNumber_Alert)' 
      GOTO QUIT        
   END 

   QUIT:
   
   /***********************************************/
   /* Std - Error Handling (Start)                */
   /***********************************************/
   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

   IF @n_Continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT > @n_StartTCnt
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

      IF CURSOR_STATUS('GLOBAL' , 'C_EMAIL') in (0 , 1)
      BEGIN
         CLOSE C_EMAIL
         DEALLOCATE C_EMAIL
      END

      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
 
   END
   ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_StartTCnt
      BEGIN
         COMMIT TRAN
      END
 
   END
   /***********************************************/
   /* Std - Error Handling (End)                  */
   /***********************************************/

END -- End Procedure

GO