SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Procedure: isp_PalletLabel                                    */
/* Creation Date: 13-Jan-2011                                           */
/* Copyright: IDS                                                       */
/* Written by: Chew KP                                                  */
/*                                                                      */
/* Purpose:  SOS#200915 - Pallet Label Printing for IDSUS .             */
/*                                                                      */
/* Called By:  RDT - Print Carton Label                                 */
/*                                                                      */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 28-Jan-2019  TLTING_ext 1.1  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_PalletLabel] (
            @c_DropID       NVARCHAR(18)     = ''
          , @c_OrderKey     NVARCHAR(10)     = ''
          , @c_TemplateID   NVARCHAR(60)  = ''
          , @c_PrinterID    NVARCHAR(215) = ''
          , @c_FileName     NVARCHAR(215) = ''
          --, @c_CartonNoParm NVARCHAR(5)   = ''
          , @c_Storerkey    NVARCHAR(18)  = '' 
			 , @c_FilePath     NVARCHAR(120) = '')
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_WARNINGS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF
   SET ANSI_NULLS OFF

   DECLARE @b_debug int
   SET @b_debug = 0
/*********************************************/
/* Variables Declaration (Start)             */
/*********************************************/

   DECLARE @n_StartTCnt  int
   SELECT  @n_StartTCnt = @@TRANCOUNT

   DECLARE @n_continue int
         , @c_errmsg NVARCHAR(255)
         , @b_success int
         , @n_err int
         , @c_ExecStatements nvarchar(4000)
         , @c_ExecArguments nvarchar(4000)

   DECLARE @c_BISOCntryCode    NVARCHAR(10)
        , @c_CCompany         NVARCHAR(45)
        , @c_BookingReference NVARCHAR(30)
        , @c_CarrierKey        NVARCHAR(10)
        , @c_ExternOrderkey   NVARCHAR(50)   --tlting_ext
        , @c_MultiLoad        NVARCHAR(255)
        , @d_Userdefine07     datetime
        , @d_ProcessDate      datetime
        , @n_CartonCount      int
        , @c_PrintedBy        NVARCHAR(20)
        , @c_Loadkey          NVARCHAR(10)
        , @n_LoopCount        int

      

   -- Extract from General
   DECLARE @c_Date NVARCHAR(8)
         , @c_Time NVARCHAR(8)
         , @c_DateTime NVARCHAR(14)
         , @n_SeqNo int
         , @n_SeqLineNo int
         , @n_licnt int
         , @c_licnt NVARCHAR(2)
         , @n_PageNumber int
         , @n_CartonNoParm int
         , @c_ColumnName	 NVARCHAR(100)
         , @c_ColumnValue	 NVARCHAR(255)
			, @c_PDColumnName	 NVARCHAR(100)
         , @c_PDColumnValue NVARCHAR(255)
			, @n_CountPD			INT
         , @c_LabelLineNo	 NVARCHAR(5)
         , @n_RowCount        INT
         

   -- SOS127598
   DECLARE @n_IsRDT INT
   EXECUTE RDT.rdtIsRDT @n_IsRDT OUTPUT

   -- Variables Initialization
   SET @c_ExecStatements = ''
   SET @c_ExecArguments = ''
   SET @n_continue = 0
   SET @c_errmsg = ''
   SET @b_success = 0
   SET @n_err = 0
   SET @c_BISOCntryCode    = ''
   SET @c_CCompany         = ''
   SET @c_BookingReference = ''
   SET @c_CarrierKey       = ''
   SET @c_ExternOrderkey   = ''
   SET @c_MultiLoad        = ''
   SET @n_CartonCount      = 0
   SET @c_PrintedBy        = ''
   
   SELECT @c_PrintedBy = suser_name()  

   SET @c_Date = RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, GETDATE()))), 2) + '/'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, GETDATE()))), 2) + '/'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, GETDATE()))), 2) + '/'

   SET @c_Time = RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, GETDATE()))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, GETDATE()))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, GETDATE()))), 2) + ':'

   SET @c_DateTime = RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, GETDATE()))), 4)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, GETDATE()))), 2)
                   + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(SECOND, GETDATE()))), 2)

   -- Retrieve StorerKey and BuyerPO from ORDERS
--   SELECT DISTINCT @c_StorerKey = StorerKey 
--     FROM ORDERS WITH (NOLOCK)
--    WHERE ORDERS.OrderKey = @c_OrderKey

--   IF ISNULL(RTRIM(@c_CartonNoParm),'') <> '' AND ISNUMERIC(@c_CartonNoParm) = 1
--   BEGIN
--      SET @n_CartonNoParm = CAST(@c_CartonNoParm AS INT)
--   END

/*********************************************/
/* Variables Declaration (End)               */
/*********************************************/



/*********************************************/
/* Temp Tables Creation (Start)              */
/*********************************************/
-- (YokeBeen01) - Start
--    IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') <> ''
--       DROP TABLE #TempGSICartonLabel_XML
--
--    IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_Rec'),'') <> ''
--       DROP TABLE #TempGSICartonLabel_Rec
-- (YokeBeen01) - End

   IF @b_debug = 2
   BEGIN
      SELECT 'Creat Temp tables - #TempGSICartonLabel_XML...'
   END

   IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_XML'),'') = ''
   BEGIN
      -- Start Ricky for SOS161629
/*      CREATE TABLE #TempGSICartonLabel_XML
               ( SeqNo int IDENTITY(1,1),  -- Temp table's PrimaryKey
                 LineText NVARCHAR(1500)    -- XML column
               )
      CREATE INDEX Seq_ind ON #TempGSICartonLabel_XML (SeqNo)  */

      CREATE TABLE #TempGSICartonLabel_XML
               ( SeqNo int IDENTITY(1,1) Primary key,  -- Temp table's PrimaryKey
                 LineText NVARCHAR(1500)                -- XML column
               )      
      -- End Ricky for SOS161629               
   END

   IF @b_debug = 2
   BEGIN
      SELECT 'Creat Temp tables - #TempGSICartonLabel_Rec...'
   END



   IF ISNULL(OBJECT_ID('tempdb..#TempGSICartonLabel_Rec'),'') = ''
   BEGIN

      CREATE TABLE #TempGSICartonLabel_Rec
               (  SeqNo                                           int IDENTITY(1,1),   
                  SeqLineNo as SeqNo,
                  BISOCntryCode                                NVARCHAR(10) default '',
                  CCompany                                     NVARCHAR(45) default '',
                  BookingReference                             NVARCHAR(30) default '',
                  CarrieKey                                    NVARCHAR(10) default '',
                  ExternOrderkey                               NVARCHAR(50) default '',  --tlting_ext
                  MultiLoad                                    NVARCHAR(255)default '',
                  Userdefine07                                 NVARCHAR(30) default '',
                  ProcessDate                                  NVARCHAR(10) default '',
                  CartonCount                                  NVARCHAR(10) default '',
                  DropID                                       NVARCHAR(18) default '',
                  PrintedBy                                    NVARCHAR(20) default '',
                  Primary key (SeqNo)
               )

--      CREATE clustered INDEX Seq_ind ON #TempGSICartonLabel_Rec (SeqNo)     -- Added by tlting01, comment by Ricky for SOS161629
--      CREATE INDEX Seq_ind2 ON #TempGSICartonLabel_Rec (SeqNo,  OrderKey)   -- Ricky for SOS161629
   END

/*********************************************/
/* Temp Tables Creation (End)                */
/*********************************************/
 DECLARE @n_RunNumber int
 SELECT @n_RunNumber = 0
/*********************************************/
/* Data extraction (Start)                   */
/*********************************************/

   IF @b_debug = 1
   BEGIN
      SELECT 'Extract records into Temp table - #TempGSICartonLabel_Rec...'
   END
   -- Extract records into Temp table.
      SET @n_LoopCount = 1
      DECLARE Cur_Load CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
      
      SELECT DISTINCT PD.Storerkey , 
                      O.ExternOrderkey , 
                      DropID.Loadkey,
                      O.C_Company,
                      M.UserDefine07,
                      M.BookingReference,
                      M.CarrierKey
	   FROM dbo.DropID DropID WITH (NOLOCK)
      INNER JOIN dbo.DropIDDetail DD WITH (NOLOCK) on DD.DropID = DropID.DropID
      INNER JOIN dbo.PackDetail PD WITH (NOLOCK) on PD.LabelNo = DD.ChildID
      INNER JOIN dbo.PackHeader PH WITH (NOLOCK) on PH.PickSlipNo = PD.PickSlipNo 
      INNER JOIN dbo.Orders O WITH (NOLOCK) on O.Orderkey = PH.Orderkey
      INNER JOIN dbo.MBOL M WITH (NOLOCK) on M.MBOLKEY = O.MBOLKEY
      WHERE DropID.DropID = @c_DropID

      OPEN Cur_Load
      FETCH NEXT FROM Cur_Load INTO @c_Storerkey, @c_ExternOrderkey, @c_Loadkey , @c_CCompany, @d_UserDefine07, @c_BookingReference, @c_CarrierKey

      WHILE (@@FETCH_STATUS <> -1)
      BEGIN
         
         IF @n_LoopCount = 1
         BEGIN
            SET @c_MultiLoad = @c_Loadkey 
         END
         ELSE
         BEGIN
            SET @c_MultiLoad = @c_MultiLoad + ',' + @c_Loadkey 
         END
         
         FETCH NEXT FROM Cur_Load INTO @c_Storerkey, @c_ExternOrderkey, @c_Loadkey , @c_CCompany, @d_UserDefine07, @c_BookingReference, @c_CarrierKey
      
      END
      CLOSE Cur_Load
      DEALLOCATE Cur_Load
      
      
      SELECT @n_CartonCount = Count(DISTINCT ChildID) , 
             @d_ProcessDate = MIN(ADDDATE) 
      FROM dbo.DropIDDetail WITH (NOLOCK)
      WHERE DropID =  @c_DropID
      
      SELECT @c_BISOCntryCode = B_ISOCntryCode
      FROM dbo.Storer WITH (NOLOCK)
      WHERE Storerkey = @c_Storerkey 

      
   INSERT INTO #TempGSICartonLabel_Rec
         (        BISOCntryCode                                
                  ,CCompany                                  
                  ,BookingReference                          
                  ,CarrieKey                                 
                  ,ExternOrderkey                            
                  ,MultiLoad                                 
                  ,Userdefine07                              
                  ,ProcessDate                               
                  ,CartonCount                                 
                  ,DropID                                      
                  ,PrintedBy )                                  
   VALUES (   LEFT(ISNULL(RTRIM(@c_BISOCntryCode),''), 10)
            , REPLACE(LEFT(ISNULL(RTRIM(@c_CCompany),''), 45),'&','&amp;')
            , LEFT(ISNULL(RTRIM(@c_BookingReference),''), 30)
            , LEFT(ISNULL(RTRIM(@c_CarrierKey),''), 10)
            , LEFT(ISNULL(RTRIM(@c_ExternOrderkey),''), 50)   --tlting_ext
            , LEFT(ISNULL(RTRIM(@c_MultiLoad),''), 255)
            , CASE WHEN ISNULL(@d_UserDefine07,'') <> '' THEN  RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(YEAR, @d_UserDefine07))), 4) + '-'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MONTH, @d_UserDefine07))), 2) + '-'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(DAY, @d_UserDefine07))), 2)  + ' '   -- @c_Date
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(HOUR, @d_UserDefine07))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(MINUTE, @d_UserDefine07))), 2) + ':'
               + RIGHT(RTRIM('0' + CONVERT(Char, DATEPART(SECOND, @d_UserDefine07))), 2) -- @c_Time
              ELSE ''
              END 
--   			,RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, @d_UserDefine07))), 4) + 
--              + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, @d_UserDefine07))), 2) + 
--              + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, @d_UserDefine07))), 2) 
			  ,RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(YEAR, @d_ProcessDate))), 4) +
              + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, @d_ProcessDate))), 2) + 
              + RIGHT(RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, @d_ProcessDate))), 2) 
			  , RIGHT(ISNULL(RTRIM(CONVERT(CHAR, @n_CartonCount)),0), 5)
			  , LEFT(ISNULL(RTRIM(@c_DropID),''), 18)
			  , LEFT(ISNULL(RTRIM(@c_PrintedBy),''), 20) )
         


   IF @b_debug = 2
   BEGIN
      SELECT '#TempCSICartonLabel_Rec.. '
      SELECT * FROM #TempGSICartonLabel_Rec
   END
   

/*********************************************/
/* Data extraction (Start)                   */
/*********************************************/
/*********************************************/
/* Cursor Loop - XML Data Insertion (Start)  */
/*********************************************/
   DECLARE @n_FieldID int
         , @c_ColName NVARCHAR(225)
         , @c_ColValues NVARCHAR(1000)
         , @n_ColID int
         , @n_ColCnt int
         , @n_LIColID int

   SET @n_FieldID = 0
   SET @c_ColValues = ''
   SET @c_ColName = ''
   SET @n_ColID = 0
   SET @n_LIColID = 0

   
      -- Insert <?xml Version>
      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('<?xml version="1.0" encoding="UTF-8" standalone="no"?>', @@SPID)

      -- Insert <labels>
      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('<labels _FORMAT = "' + ISNULL(RTRIM(@c_FilePath),'') + '\' + ISNULL(RTRIM(@c_TemplateID),'') + '" _QUANTITY="1" _PRINTERNAME="' +
              ISNULL(RTRIM(@c_PrinterID),'') + '" _JOBNAME="Shipping">', @@SPID)
   
   

/*********************************************/
/* Cursor Loop - File level                  */
/*********************************************/
   
      IF @b_debug = 1
      BEGIN
         SELECT 'GSI_Label_Cur.. '
         SELECT SeqLineNo, SeqNo
           FROM #TempGSICartonLabel_Rec
          ORDER BY SeqLineNo, SeqNo
      END
	
	 -- Insert <label> - record level start
   INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
   VALUES ('<label>', @@SPID)

   DECLARE GSI_Label_Cur CURSOR LOCAL FAST_FORWARD READ_ONLY FOR
   SELECT Name FROM tempdb.sys.columns (NOLOCK) 
   WHERE object_id = object_id('tempdb..#TempGSICartonLabel_Rec')
   
   OPEN GSI_Label_Cur
   
   FETCH NEXT FROM GSI_Label_Cur INTO @c_ColumnName
   
   
   WHILE (@@FETCH_STATUS <> -1)
   BEGIN

/*********************************************/
/* Cursor Loop - Record/Line level           */
/*********************************************/
    
         
         -- Start Generating XML Part1 -- Common Information(Start)
         
			-- Do No Print Extract First 2 Column --
			IF ISNULL(RTRIM(@c_ColumnName),'') <> 'SeqNo' AND ISNULL(RTRIM(@c_ColumnName),'') <> 'SeqLineNo'
			BEGIN
			   
				SET @c_ExecStatements = ''
				SET @c_ExecArguments = ''

				SET @c_ExecStatements = N'SELECT @c_ColumnValue = [' + ISNULL(RTRIM(@c_ColumnName),'') + ']' + 
												 ' FROM #TEMPGSICARTONLABEL_Rec ' 
												 --' WHERE SeqNo = ' + ISNULL(RTRIM(@n_SeqNo),0) +
												 --' AND SeqLineNo = ' + ISNULL(RTRIM(@n_SeqLineNo),0)

				SET @c_ExecArguments = N'@c_ColumnValue NVARCHAR(255) OUTPUT '

				IF @b_debug = 2
					SELECT @c_ExecStatements, @c_ExecArguments

				EXEC sp_ExecuteSql @c_ExecStatements, @c_ExecArguments, @c_ColumnValue OUTPUT
	      
	         
				INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
						VALUES ('<variable name="' + ISNULL(RTRIM(@c_ColumnName),0) + '">' +
									ISNULL(RTRIM(@c_ColumnValue),'') + '</variable>', @@SPID)
	    
				-- Start Generating XML Part1 -- Common Information(End)
			   
         END

      FETCH NEXT FROM GSI_Label_Cur INTO @c_ColumnName

      
   END -- END WHILE (@@FETCH_STATUS <> -1)

   CLOSE GSI_Label_Cur
   DEALLOCATE GSI_Label_Cur
	
	        -- Insert <label> - record level end
         INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
         VALUES ('</label>', @@SPID)
         
      -- Insert </labels>
      INSERT INTO RDT.RDTGSICartonLabel_XML (LineText, SPID)
      VALUES ('</labels>', @@SPID)
  

   WHILE @@TRANCOUNT > 0
      COMMIT TRAN

   WHILE @@TRANCOUNT < @n_StartTCnt
      BEGIN TRAN

	-- Clean Up Temp Tabel	
	DROP Table #TempGSICartonLabel_Rec
	
--BEGIN
      -- Select list of records
      --SELECT SeqNo, LineText FROM #TempGSICartonLabel_XML
--END

END
/*********************************************/
/* Cursor Loop - XML Data Insertion (End)    */
/*********************************************/

SET QUOTED_IDENTIFIER OFF

GO