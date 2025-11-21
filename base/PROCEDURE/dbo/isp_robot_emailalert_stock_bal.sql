SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/  
/* Stored Procedure: isp_robot_EmailAlert_stock_bal                     */  
/* Creation Date: 27-Jun-2018                                           */  
/* Copyright: IDS                                                       */  
/* Written by: CSCHONG                                                  */  
/*                                                                      */  
/* Purpose: WMS-5334 - Robot Inv Bal Email Alert                        */  
/*                                                                      */  
/* Return Status: None                                                  */  
/*                                                                      */  
/* Usage: generate csv and send mail to show robot inventory balance    */  
/*                                                                      */  
/* Local Variables:                                                     */  
/*                                                                      */  
/* Called By: SQL Schedule Job                                          */  
/*                                                                      */  
/* PVCS Version: 1.0                                                    */  
/*                                                                      */  
/* Version: 5.4                                                         */  
/*                                                                      */  
/* Data Modifications:                                                  */  
/*                                                                      */  
/* Updates:                                                             */  
/* Date        Author    Ver.  Purposes                                 */  
/* 12-Jun-2019 WinSern   1.1   INC0736903 - Revised Script (WinSern01)  */  
/************************************************************************/  

CREATE PROC [dbo].[isp_robot_EmailAlert_stock_bal]   
        @b_Debug     INT = 0 
      , @c_ErrMsg    NVARCHAR(250)  OUTPUT
AS   
BEGIN  
   SET NOCOUNT ON  
   SET ANSI_NULLS OFF    
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF  
  
   DECLARE @n_StartTCnt       INT 
         , @n_Err             INT 

   DECLARE @n_FileExists        INT
         , @c_Subject           VARCHAR(256)
         , @c_Recipient         VARCHAR(625)
         , @c_Attachment        VARCHAR(625)
         , @c_EmailBody         VARCHAR(2048)
			, @n_WorkFolderExists  INT             
         , @c_WorkFilePath      NVARCHAR(215)  
			, @c_storer            NVARCHAR(20)
			, @c_Facility          NVARCHAR(10)
			, @c_GetFacility       NVARCHAR(10)
			, @c_sku               NVARCHAR(20)
			, @n_wmsqty            INT
			, @n_robotqty          INT
			, @n_DiffQty           INT
			, @c_csv_value         NVARCHAR(MAX)
			, @c_csv_header        NVARCHAR(MAX)
			, @c_csv_file          NVARCHAR(max)
			, @c_demiliter         NVARCHAR(5)
			, @b_success           NVARCHAR(5)
			, @c_filename          NVARCHAR(150)
			, @c_csv_fvalue        NVARCHAR(MAX)
			, @c_Status            NVARCHAR(10)
			, @c_storerkey         NVARCHAR(20)
			, @c_getstorerkey      NVARCHAR(20)
			, @c_sqlinsert         NVARCHAR(4000)
			, @c_sqlselect         NVARCHAR(4000)
			, @c_sql               NVARCHAR(4000)
			, @c_DTSITFDB          NVARCHAR(30)
			, @n_getwmsqty         INT
			, @c_getsku            NVARCHAR(20)

   SET @n_StartTCnt     = @@TRANCOUNT  
   SET @n_Err           = 0 
   SET @c_ErrMsg        = ''
   SET @c_Status        = '' 
   SET @n_FileExists    = 0    

   SET @c_Subject       = 'ROBOT INVENTORY BALANCE REPORT(' + convert(nvarchar(10),getdate(),121) + ')'  
   SET @c_Recipient     = ''   
   SET @c_Attachment    = '' 
   SET @c_EmailBody     = 'Robot Inventory Report Balance'   
	SET @c_demiliter     = ','
                         
   WHILE @@TRANCOUNT > 0                  
      COMMIT TRAN     
		
		CREATE TABLE #TMPROBOT
		(Facility      NVARCHAR(10),
		 Storerkey     NVARCHAR(20),
		 RSKU          NVARCHAR(20),
		-- file_key      INT,
		 RQty          INT,
		 WMSQty        INT
		)                  

   If @b_Debug = 1
   BEGIN
      SELECT 'Send Email - Start.'
   END

   --WHILE 1=1 -- LOOP Send Email
   --BEGIN 
      SET @c_Status = '9'
      SET @c_ErrMsg = ''

      SET @c_Recipient = ''
      SET @c_Attachment = ''

		 SET @c_DTSITFDB = ''
   
    SELECT @c_DTSITFDB = NSQLValue 
	 FROM NSQLCONFIG WITH (NOLOCK)
    WHERE ConfigKey='WebServiceLogDBName'

	 SET @c_sqlinsert = N'INSERT INTO #TMPROBOT (Facility,Storerkey,RSKU,RQty,WMSQty)'

   DECLARE CUR_storer CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
    SELECT DISTINCT short,notes,storerkey
    FROM  CODELKUP  (NOLOCK)
	 WHERE listname = 'ROBOTINFO'
  
   OPEN CUR_storer   
     
   FETCH NEXT FROM CUR_storer INTO @c_facility,@c_Recipient,@c_storerkey 
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   



      IF LTRIM(RTRIM(@c_Recipient)) = '' 
      BEGIN
         SET @c_Status = 'E'
         SET @c_ErrMsg = 'No Recipients Email Found'
         GOTO EXIT_WITH_ERROR
      END

		SET @c_sqlselect = ''
		SET @c_sql = ''

		SET @c_sqlselect = N'SELECT wsc.facility,wsc.storerkey,wsc.sku,wsc.totalsoh,0'
		                    +' FROM ' + @c_DTSITFDB + '..wmscustsoh wsc WITH (NOLOCK) '
								  +' WHERE wsc.facility =@c_facility and wsc.storerkey = @c_storerkey '
								  +' AND wsc.file_key = (select MAX(file_key) FROM ' + @c_DTSITFDB + '..wmscustsoh wsc1 WITH (NOLOCK) '
	                       + ' WHERE wsc1.facility=wsc.facility and wsc1.storerkey = wsc.storerkey)'
								--  +' GROUP BY  wsc.facility,wsc.storerkey,wsc.sku,wsc.totalsoh,file_key '
								  +' ORDER BY wsc.sku desc'

      SET @c_sql = @c_sqlinsert + CHAR(13) + @c_sqlselect

		 EXEC sp_executesql @c_sql,                                 
                    N'@c_facility NVARCHAR(10),@c_storerKey NVARCHAR(20)', 
                     @c_facility,@c_storerKey 	

		SET @c_csv_Value = ''

	 DECLARE CUR_sku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
   --SELECT DISTINCT lli.sku,sum(DISTINCT(lli.qty-lli.qtypicked)) as WMS_Qty,--TB.RQty as RobotQty,			--WinSern01
   SELECT lli.sku,sum((lli.qty-lli.qtypicked)) as WMS_Qty,--TB.RQty as RobotQty,							--WinSern01
	--(sum(DISTINCT(lli.qty-lli.qtypicked))-TB.RQty) as Discrepancy_Qty,
	lli.storerkey
	FROM lotxlocxid lli WITH (NOLOCK) 
	--JOIN cndtsitf..wmscustsoh wsc WITH (NOLOCK) ON wsc.sku = lli.sku and wsc.storerkey = lli.storerkey
	--JOIN codelkup c with (nolock) on c.listname = 'ROBOTINFO' and c.short=wsc.facility and c.storerkey = wsc.storerkey
	--JOIN #TMPROBOT TB ON TB.rsku = lli.sku and TB.storerkey = lli.storerkey
	JOIN LOC L WITH (NOLOCK) ON L.loc = lli.loc
	where lli.storerkey=@c_storerkey
	and L.LocationType = 'DYNPPICK' and L.LocationCategory = 'ROBOT'
	group by lli.sku,lli.storerkey
  
   OPEN CUR_sku   
     
   FETCH NEXT FROM CUR_sku INTO @c_sku,@n_wmsqty,@c_getstorerkey
     
   WHILE @@FETCH_STATUS <> -1  
   BEGIN   

	IF NOT EXISTS (SELECT 1 FROM #TMPROBOT 
	               WHERE rsku = @c_sku )
   BEGIN
	   INSERT INTO #TMPROBOT (Facility,Storerkey,RSKU,RQty,WMSQty)
		VALUES (@c_facility,@c_getstorerkey,@c_sku,0,@n_wmsqty)
	END
	ELSE
	BEGIN
	  UPDATE #TMPROBOT
	  SET WMSQty = @n_wmsqty
	  where rsku=@c_sku
	  and storerkey = @c_getstorerkey
	END

	FETCH NEXT FROM CUR_sku INTO @c_sku,@n_wmsqty,@c_getstorerkey
	END
	CLOSE CUR_sku
	DEALLOCATE CUR_sku


    DECLARE CUR_robotsku CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
	  SELECT  facility,storerkey,rsku,WMSQty,RQty, (WMSQty -RQty) 
     FROM #TMPROBOT
	  order by rsku

	  OPEN CUR_robotsku   
     
     FETCH NEXT FROM CUR_robotsku INTO @c_getfacility,@c_getstorerkey,@c_getsku,@n_getwmsqty,@n_robotqty,@n_DiffQty
     
     WHILE @@FETCH_STATUS <> -1  
     BEGIN   

	    SET @c_csv_Value = @c_getstorerkey + @c_demiliter + @c_getfacility + @c_demiliter + @c_getsku + @c_demiliter + CAST(@n_getwmsqty as NVARCHAR(10)) 
	                 + @c_demiliter + cast(@n_robotqty as nvarchar(10)) + @c_demiliter + CAST(@n_DiffQty as nvarchar(10)) + CHAR(13)

	    SET @c_csv_fvalue = @c_csv_fvalue + @c_csv_Value  

	  FETCH NEXT FROM CUR_robotsku INTO @c_getfacility,@c_getstorerkey,@c_getsku,@n_getwmsqty,@n_robotqty,@n_DiffQty
	  END

	  CLOSE CUR_robotsku
	  DEALLOCATE CUR_robotsku


		IF ISNULL(@c_csv_fvalue,'') <> ''
		BEGIN

		SET @c_csv_file = ''

		SET @c_csv_header = 'Storerkey,Facility,sku,wms_qty,robot_qty,Discrepancy_Qty'
		SET @c_WorkFilePath = 'D:\Mail\Attachment\' 
		SET @c_filename = @c_storerkey +'_Robot_Inv_Bal' + convert(nvarchar(10),getdate(),121) + '.csv'

		SET @c_csv_file = @c_csv_header + CHAR(13) + @c_csv_fvalue


		
		 EXEC isp_WriteStringToFile
                  @c_csv_file,
                  @c_WorkFilePath,
                  @c_Filename,
                  2, -- IOMode 2 = ForWriting ,8 = ForAppending
                  @b_success Output
						,-2

            IF @b_success <> 1
            BEGIN
               SELECT @c_ErrMsg='Error Writing CSV file.(isp_robot_EmailAlert_stock_bal)' 
               
                
               GOTO EXIT_WITH_ERROR      
            END   
				
				set @c_csv_fvalue  = '' 

				SET @c_Attachment = @c_WorkFilePath + @c_Filename
       END

      --IF LTRIM(RTRIM(@c_Attachment)) <> ''
      --BEGIN
      --   SET @n_FileExists = 0   
      --   EXECUTE @n_FileExists = [dbo].[isp_FolderFileExist]   
      --           @c_Attachment  
      --           ,1 -- 0=Folder, 1=File  

      --   IF @n_FileExists < 0   
      --   BEGIN
      --      SET @c_Status = 'E'
      --      SET @c_ErrMsg = 'Attachment: '+ LTRIM(RTRIM(@c_Attachment))  + ' File not found.'
      --   END
      --END 
     
		IF @c_Attachment <> ''
		BEGIN

		IF @b_Debug = 1
      BEGIN
         SELECT '@c_Recipient : '   + RTRIM(@c_Recipient)
         SELECT '@c_Subject : '     + RTRIM(@c_Subject)
         SELECT '@c_EmailBody : '   + RTRIM(@c_EmailBody)
         SELECT '@c_Attachment : '  + RTRIM(@c_Attachment)
      END

        BEGIN TRAN

				EXEC msdb.dbo.sp_send_dbmail 
					  @recipients        = @c_Recipient
					, @subject           = @c_Subject
					, @body              = @c_EmailBody
					, @body_format       = 'HTML'    -- Either 'Text' or 'HTML'
					, @file_attachments  = @c_Attachment

				IF @@ERROR = 0
				BEGIN 
					WHILE @@TRANCOUNT > 0
						COMMIT TRAN
				END
				ELSE
				BEGIN
					ROLLBACK TRAN 
					SET @n_Err = 68005
					SET @c_ErrMsg = 'NSQL' + CONVERT(CHAR(5),ISNULL(@n_Err,0))  
										  + ': Send email fail. (isp_robot_EmailAlert_stock_bal)' 
					GOTO EXIT_WITH_ERROR        
				END 
       END
   FETCH NEXT FROM CUR_storer INTO @c_facility,@c_Recipient,@c_storerkey 
   END
	CLOSE CUR_storer 

   --END -- WHILE 1=1 -- LOOP Send Email

   If @b_Debug = 1
   BEGIN
      SELECT 'Send Email - End.'
   END

   --Clear ErrMsg if process successful, return empty string
   SET @c_ErrMsg = ''

	DROP TABLE #TMPROBOT

EXIT_WITH_ERROR:  

   WHILE @@TRANCOUNT < @n_StartTCnt  
   BEGIN  
      BEGIN TRAN                      
   END

   WHILE @@TRANCOUNT > @n_StartTCnt  
   BEGIN           
      COMMIT TRAN  
   END  
  
END -- Procedure


GO