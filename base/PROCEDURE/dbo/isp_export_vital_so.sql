SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure isp_Export_Vital_SO : 
--

CREATE PROC [dbo].[isp_Export_Vital_SO] (
   @c_SourceDBName	   NVARCHAR(20)
,  @c_FilePrefix        NVARCHAR(10) -- ISG
,  @b_Success  int        =0       OUTPUT
,  @n_err      int        =0       OUTPUT
,  @c_errmsg   NVARCHAR(250)  =NULL    OUTPUT
)
AS 
SET NOCOUNT ON
SET ANSI_DEFAULTS OFF  

DECLARE @b_debug     int  
DECLARE @n_continue  int 
DECLARE @n_StartTCnt int

SET @b_debug = 0
SET @n_continue = 1 
SET @n_StartTCnt = @@TRANCOUNT 


DECLARE @c_OrderKey		      NVARCHAR(10)
		, @c_OrderType   	      NVARCHAR(10)
		, @c_OrderlineNo   	   NVARCHAR(5)
		, @c_Transmitlogkey     NVARCHAR(10)
		, @c_ExecStatements  	nvarchar(4000)
      , @c_Externlineno       NVARCHAR(3)
      , @c_FileName           NVARCHAR(20)

SELECT @c_SourceDBName = dbo.fnc_RTRIM(@c_SourceDBName)

CREATE TABLE [#TempVTSO] (
				 [Key1] [varchar] (10) NULL , -- orderkey
			    [Key3] [varchar] (20) NULL , -- storerkey
				 [TransmitLogKey] [varchar] (10) NULL ,
             [OrderLineno] [varchar] (5) NULL , 
			    [RowId] [int] IDENTITY (1, 1) NOT NULL )

SELECT @c_ExecStatements = ''

-- Retrieve orderkey and TransmitLogKey from TransmitLog3 table
SELECT @c_ExecStatements = N'INSERT INTO #TempVTSO (Key1, Key3, TransmitLogKey, OrderLineno) '
								    + 'SELECT TransmitLog3.Key1, TransmitLog3.Key3, '
                            + 'TransmitLog3.TransmitLogKey, OrderDetail.OrderLineNumber '
								    + 'FROM ' + dbo.fnc_RTRIM(@c_SourceDBName) + '..TransmitLog3 TransmitLog3 (NOLOCK) '
								    + 'JOIN ' + dbo.fnc_RTRIM(@c_SourceDBName) + '..ORDERDETAIL ORDERDETAIL (NOLOCK) ' 
								    + 'ON (TransmitLog3.Key1 = ORDERDETAIL.Orderkey) '
  							       + 'WHERE TransmitLog3.Tablename = ''VITALSO'' '  
								    + 'AND TransmitLog3.TransmitFlag = ''1'' ' 
								    + 'ORDER BY TransmitLog3.Key1, OrderDetail.OrderLineNumber '
                            
IF @b_debug = 1 
BEGIN
  SELECT @c_ExecStatements
END

EXEC sp_executesql @c_ExecStatements 

-- Insert Records
DECLARE INS_ORDHEADER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
   SELECT DISTINCT Key1 FROM #TempVTSO
   ORDER BY Key1
   
OPEN INS_ORDHEADER 

-- Get Begin OrderHeader Info 
FETCH NEXT FROM INS_ORDHEADER INTO @c_Orderkey

WHILE @@FETCH_STATUS <> -1 
BEGIN
	BEGIN TRAN
		
		SELECT @c_ExecStatements = ''			
		
		SELECT @c_ExecStatements = N'INSERT INTO DataStream_Out '
								 + '(DataStream, LineText) '
								 + ' SELECT ''0001'', '   -- to be determined later
                         + '''H|'' + '
                         + 'dbo.fnc_RTRIM(Orderkey) + ''|'' + '
                         + 'dbo.fnc_RTRIM(Storerkey) + ''|'' + '
                         + 'dbo.fnc_RTRIM(ExternOrderkey) + ''|'' + ' 
                         + 'RIGHT(dbo.fnc_RTRIM(CONVERT(CHAR, DATEPART(YEAR, OrderDate))),4) + ' 
                         + 'RIGHT(dbo.fnc_RTRIM(''0'' + CONVERT(CHAR, DATEPART(MONTH, OrderDate))), 2) + '
                         + 'RIGHT(dbo.fnc_RTRIM(''0'' + CONVERT(CHAR, DATEPART(DAY, OrderDate))), 2) + ''|'' + '
                         + 'RIGHT(dbo.fnc_RTRIM(CONVERT(CHAR, DATEPART(YEAR, DeliveryDate))),4) + '
                         + 'RIGHT(dbo.fnc_RTRIM(''0'' + CONVERT(CHAR, DATEPART(MONTH, DeliveryDate))), 2) + '
                         + 'RIGHT(dbo.fnc_RTRIM(''0'' + CONVERT(CHAR, DATEPART(DAY, DeliveryDate))), 2) + ''|'' +  '
                         + 'dbo.fnc_RTRIM(ConsigneeKey) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Contact1) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Contact2) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Company) + ''|'' + ' 
                         + 'dbo.fnc_RTRIM(C_Address1) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Address2) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Address3) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Address4) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_City) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_State) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Zip) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Country) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_ISOCntryCode) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Phone1) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Phone2) + ''|'' + '
                         + 'dbo.fnc_RTRIM(C_Fax1) + ''|'' +  '
                         + 'dbo.fnc_RTRIM(C_Fax2) + ''|'' + '
                         + 'dbo.fnc_RTRIM(BuyerPO) + ''|'' + '
                         + 'dbo.fnc_RTRIM(IncoTerm) + ''|'' + ' 
                         + 'dbo.fnc_RTRIM(PmtTerm) + ''|'' + '
                         + 'dbo.fnc_RTRIM(Type) + ''|'' + '
                         + 'dbo.fnc_RTRIM(OrderGroup) + ''|'' + '
                         + 'dbo.fnc_RTRIM(MBOLKey) + ''|'' + '
                         + 'dbo.fnc_RTRIM(InvoiceNo) + ''|'' + ' 
                         + 'dbo.fnc_RTRIM(CONVERT (NChar(53), GrossWeight)) + ''|'' + '
                         + 'dbo.fnc_RTRIM(CONVERT (NChar(53), Capacity)) '
								 + 'FROM ' + dbo.fnc_RTRIM(@c_SourceDBName) + '..ORDERS ORDERS (NOLOCK) '
								 + 'WHERE ORDERS.Orderkey = N''' + dbo.fnc_RTRIM(@c_Orderkey) + ''' '


            IF @b_debug = 1
            BEGIN   
	            print @c_ExecStatements
            END 

           EXEC sp_executesql @c_ExecStatements

	   IF @@ERROR <> 0 
	   BEGIN
	      ROLLBACK TRAN 
	   END
	   ELSE
	   BEGIN
	      SELECT 'Insert Header Into DataStream_Out table is Done !'
	      COMMIT TRAN 
	   END 

   DECLARE INS_ORDDETAIL CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
       SELECT Orderlineno FROM #TempVTSO
       WHERE Key1 = @c_Orderkey
       ORDER BY Orderlineno    
      
   OPEN  INS_ORDDETAIL 
   
   FETCH NEXT FROM INS_ORDDETAIL INTO @c_OrderlineNo
   
   WHILE @@FETCH_STATUS <> -1
   BEGIN
     BEGIN TRAN
		
		SELECT @c_ExecStatements = ''			
		
		SELECT @c_ExecStatements = N'INSERT INTO DataStream_Out '
								 + '(DataStream, LineText) '
								 + ' SELECT ''0001'', '   -- to be determined later
                         + '''D|'' + '
                         + 'dbo.fnc_RTRIM(Orderkey) + ''|'' + '
                         + 'dbo.fnc_RTRIM(ExternOrderkey) + ''|'' + '
                         + 'dbo.fnc_RTRIM(ExternLineNo) + ''|'' + ' 
                         + 'dbo.fnc_RTRIM(Sku) + ''|'' + '
                         + 'dbo.fnc_RTRIM(Storerkey) + ''|'' + '
                         + 'dbo.fnc_RTRIM(CONVERT (NChar(10), OriginalQty)) + ''|'' + '
                         + 'dbo.fnc_RTRIM(UOM) + ''|'' + '
                         + 'dbo.fnc_RTRIM(CONVERT (NChar(53), UnitPrice)) + ''|'' + ' 
                         + 'dbo.fnc_RTRIM(CONVERT (NChar(53), GrossWeight)) + ''|'' + '
                         + 'dbo.fnc_RTRIM(CONVERT (NChar(53), Capacity)) + ''|'' + '
                         + 'dbo.fnc_RTRIM(ExternPOKey) ' 
								 + 'FROM ' + dbo.fnc_RTRIM(@c_SourceDBName) + '..ORDERDETAIL ORDERDETAIL (NOLOCK) '
								 + 'WHERE ORDERDETAIL.Orderkey = N''' + dbo.fnc_RTRIM(@c_Orderkey) + ''' '
                         + 'AND ORDERDETAIL.OrderLineNumber = N''' + dbo.fnc_RTRIM(@c_OrderlineNo) + ''' '

            IF @b_debug = 1
            BEGIN   
	            print @c_ExecStatements
            END 

           EXEC sp_executesql @c_ExecStatements

	   IF @@ERROR <> 0 
	   BEGIN
	      ROLLBACK TRAN 
	      
	   END
	   ELSE
	   BEGIN
	      SELECT 'Insert Detail Into DataStream_Out table is Done !'
	      COMMIT TRAN 
	   END 

      FETCH NEXT FROM INS_ORDDETAIL INTO @c_OrderlineNo
   END -- While detail
   CLOSE INS_ORDDETAIL
   DEALLOCATE INS_ORDDETAIL 

 FETCH NEXT FROM INS_ORDHEADER INTO @c_Orderkey  
END -- While header
CLOSE INS_ORDHEADER
DEALLOCATE INS_ORDHEADER 

-- Update Filename
SELECT @c_Filename = dbo.fnc_RTRIM(@c_FilePrefix) + 'SO' + RIGHT(dbo.fnc_RTRIM('0' + CONVERT(CHAR, DATEPART(DAY, GETDATE()))), 2) 
                     + RIGHT(dbo.fnc_RTRIM('0' + CONVERT(CHAR, DATEPART(MONTH, GETDATE()))), 2) 
                     + RIGHT(dbo.fnc_RTRIM(CONVERT(CHAR, DATEPART(YEAR, GETDATE()))),2)
                     + RIGHT(dbo.fnc_RTRIM('0' + CONVERT(CHAR, DATEPART(HOUR, GETDATE()))), 2) 
                     + RIGHT(dbo.fnc_RTRIM('0' + CONVERT(CHAR, DATEPART(MINUTE, GETDATE()))), 2)

IF @b_debug = 1
BEGIN  
 SELECT '@c_Filename', dbo.fnc_RTRIM(@c_Filename)
END

UPDATE DataStream_Out
 SET FileName = dbo.fnc_RTRIM(@c_Filename) + '.txt'
WHERE DataStream = '0001' -- to be determined
AND   Status = '0'
-- Update Filename - End

IF @n_continue=3  -- Error Occured - Process And Return  
BEGIN  
   SELECT @b_success = 0  
   IF @@TRANCOUNT > @n_starttcnt  
   BEGIN  
      ROLLBACK TRAN  
   END  
   ELSE  
   BEGIN  
      WHILE @@TRANCOUNT > @n_starttcnt  
      BEGIN  
         COMMIT TRAN  
      END  
   END  
   execute nsp_logerror @n_err, @c_errmsg, 'isp_Export_Vital_SO'  

   RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012  
   RETURN  
END  
ELSE  
BEGIN  
   SELECT @b_success = 1  
   WHILE @@TRANCOUNT > @n_starttcnt  
   BEGIN  
      COMMIT TRAN  
   END  
   RETURN  
END

GO