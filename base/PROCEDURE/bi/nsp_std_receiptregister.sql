SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/***********************************************************************
TITLE: RECEIPT REGISTER (PHWMS) https://jiralfl.atlassian.net/browse/WMS-20217

DATE				VER		CREATEDBY   PURPOSE
13-JUN-2022         1.3     CRISNAH     ADD SP TO PHWMS
13-JUL-2022          1.4     Crisnah    Migrate also to PHWMS. this is usual daily report from operations
21-FEB-2023			1.5		CRISNAH		ADD RECEIPTDETAIL.EXTERNLINENO https://jiralfl.atlassian.net/browse/WMS-21831
20-SEP-2023	  1.6	CRISNAH		MODIFY RECEIPT.NOTES REMOVE CHAR LIMIT
04-OCT-2023			1.7		CRISNAH		LEFT JOIN STORER - FONTERRA ENHANCEMENT REQUEST
************************************************************************/
-- Test:   EXEC BI.nsp_STD_ReceiptRegister '16380','1611','FinalizeDate','2022-06-06','2022-06-07','5,9'

CREATE       PROC [BI].[nsp_STD_ReceiptRegister] --NAME OF SP
	@Param_Generic_Storerkey NVARCHAR(50)
	, @Param_Generic_Facility NVARCHAR(50)
	, @Param_Generic_DateDataType NVARCHAR(50)=''
	, @Param_Generic_StartDate DATETIME
	, @Param_Generic_EndDate DATETIME
	, @Param_Receipt_Status NVARCHAR(100)=''

AS
BEGIN
 SET NOCOUNT ON;  -- keeps the output generated to a minimum 
   SET ANSI_NULLS OFF;
   SET QUOTED_IDENTIFIER OFF;
   SET CONCAT_NULL_YIELDS_NULL OFF;

	IF ISNULL(@PARAM_GENERIC_StorerKey, '') = ''
		SET @PARAM_GENERIC_StorerKey = ''
	IF ISNULL(@Param_Generic_Facility, '') = ''
		SET @Param_Generic_Facility = ''
	IF ISNULL(@Param_Receipt_Status, '') = ''
		SET @Param_Receipt_Status = '0'
	IF ISNULL(@Param_Generic_DateDataType, '') = ''
		SET @Param_Generic_DateDataType = 'adddate'

	IF (SELECT COUNT(COLUMN_NAME) FROM INFORMATION_SCHEMA.COLUMNS 
		WHERE TABLE_NAME = 'V_RECEIPT' and data_type='datetime' 
		AND COLUMN_NAME=@Param_Generic_DateDataType) = 0
	BEGIN SET @Param_Generic_DateDataType = 'ADDDATE' END	

		SET @Param_Receipt_Status = REPLACE(REPLACE(@Param_Receipt_Status,'[',''),']','')

	--SET @Param_Receipt_Status = REPLACE(REPLACE (TRANSLATE (@Param_Receipt_Status,'[ ]',''' '''),'''',''),',',''',''')

DECLARE @nRowCnt INT = 0
	   , @nDebug BIT  = 0
	   , @RowNum    INT
       , @Proc      NVARCHAR(128) = 'nsp_STD_ReceiptRegister' --NAME OF SP
       , @cParamOut NVARCHAR(4000)= ''
       , @cParamIn  NVARCHAR(4000)= '{ "PARAM_GENERIC_STORERKEY":"'    +@PARAM_GENERIC_STORERKEY+'", '
									+ ' "Param_Generic_Facility":"'    +@Param_Generic_Facility+'", '
									+ ' "Param_Generic_DateDataType ":"'    +@Param_Generic_DateDataType +'", '
                                    + ' "Param_Generic_StartDate":"'+CONVERT(NVARCHAR(19),@Param_Generic_StartDate,121)+'",'
									+ ' "Param_Generic_EndDate":"'+CONVERT(NVARCHAR(19),@Param_Generic_EndDate,121)+'", '
									+ ' "Param_Receipt_Status":"'    +@Param_Receipt_Status+'" '
									+ ' }'

DECLARE  @tVarLogId TABLE (LogId INT);
   INSERT dbo.ExecutionLog (ClientId, SP, ParamIn) OUTPUT INSERTED.LogId INTO @tVarLogId VALUES (@PARAM_GENERIC_StorerKey, @Proc, @cParamIn);

        IF OBJECT_ID('dbo.ExecDebug','u') IS NOT NULL
   BEGIN
      SELECT @nDebug = Debug
      FROM dbo.ExecDebug WITH (NOLOCK)
      WHERE UserName = SUSER_SNAME()
   END
   --*/
	DECLARE @Stmt NVARCHAR(MAX) = '' -- for dynamic SQL only
	
/****** START YOUR SELECT STATEMENT HERE USE @Stmt FOR DYNAMIC SQL ******/
set @Stmt = '
SELECT
 R.StorerKey
 ,R.Facility
 ,R.DocType
 ,R.ReceiptKey 
 ,R.ExternReceiptKey
 ,R.ReceiptGroup
 ,R.ReceiptDate
 ,R.POKey                     as ''ReceiptPOKey''
 ,R.CarrierKey
 ,R.CarrierName
 ,R.CarrierAddress1
 ,R.CarrierAddress2
 ,R.CarrierCity
 ,R.CarrierState
 ,R.CarrierReference
 ,R.WarehouseReference
 ,R.OriginCountry
 ,R.VehicleNumber
 ,R.VehicleDate
 ,R.ContainerType
 ,R.Signatory
 ,R.PlaceofIssue
 ,R.OpenQty
 ,case when R.Status = ''9'' then  ''Received'' 
	else ''Not Fully Received'' end as ''Status''  
 ,case when R.ASNStatus = ''0'' then  ''Open'' 
	when R.ASNStatus = ''9'' then ''Closed''  
	when R.ASNStatus=''INACTIVE'' then ''Inactive'' end as ''ASNStatus''
 ,R.Notes as ''Notes''
 ,R.EffectiveDate
 ,R.AddDate 
 ,R.AddWho
 ,R.RECType
 ,R.ASNReason
 ,R.UserDefine01
 ,R.UserDefine02
 ,R.UserDefine03
 ,R.UserDefine04
 ,R.UserDefine05
 ,R.UserDefine06
 ,R.UserDefine07
 ,R.UserDefine08
 ,R.UserDefine09
 ,R.UserDefine10
 ,R.FinalizeDate
 ,R.SellerName
 ,R.SellerCompany
 ,R.SellerAddress1
 ,R.SellerAddress2
 ,R.Sellerphone1
 ,R.Sellerphone2
 ,R.SellerCity
 ,R.Appointment_No
 ,RD.POKey					as ''RecDetPoKey''
 ,RD.ExternPoKey
 ,RD.POLineNumber
 ,RD.ReceiptLineNumber
 ,RD.Sku
 ,S.DESCR 					as ''SKU Description'' 
 ,(RD.QtyExpected)		as ''ExpectedPC'' 
 ,case when PA.InnerPack> 0 then ((RD.QtyExpected))/PA.InnerPack else 0  end        as ''QtyExpectedInnerPack''
 ,case when PA.CaseCnt > 0 then ((RD.QtyExpected))/PA.CaseCnt   else 0 end          as ''QtyExpectedCS'' 
 , ( RD.QtyReceived )                                                                 as ''QtyReceivedPC'' 
 ,case when PA.InnerPack> 0 then ( ( RD.QtyReceived )) / PA.InnerPack else 0  end   as ''QtyReceivedInnerPack'' 
 ,case when PA.CaseCnt>0 then ( ( RD.QtyReceived )) / PA.CaseCnt  else 0  end       as ''QtyReceivedCS''  
 ,RD.UOM
 ,RD.PackKey
 ,PA.PackUOM3
 ,PA.Qty
 ,PA.PackUOM2
 ,PA.InnerPack
 ,PA.PackUOM1
 ,PA.CaseCnt
 ,RD.PutawayLoc
 ,RD.ToLoc
 ,RD.ToId
 ,RD.Lottable01
 ,RD.Lottable02
 ,RD.Lottable03
 ,RD.Lottable04
 ,RD.Lottable05
 ,RD.Lottable06
 ,RD.Lottable07
 ,RD.Lottable08
 ,RD.Lottable09
 ,RD.Lottable10
 ,RD.Lottable11
 ,RD.Lottable12
 ,RD.Lottable13
 ,RD.Lottable14
 ,RD.Lottable15
 ,RD.UserDefine01
 ,RD.UserDefine02
 ,RD.UserDefine03
 ,RD.UserDefine04
 ,RD.UserDefine05
 ,RD.UserDefine06
 ,RD.UserDefine07
 ,RD.UserDefine08
 ,RD.UserDefine09
 ,RD.UserDefine10
 ,S.STDNETWGT
 , ( RD.QtyReceived * S.STDNETWGT ) as ''NetWgtQtyReceivedPC''
 ,case when PA.CaseCnt>0 then  ( ( ( RD.QtyReceived )) * S.STDNETWGT)  / PA.CaseCnt else 0 end   as ''NetWgtQtyReceivedCS'' 
 ,S.STDGROSSWGT
 , ( RD.QtyReceived * S.STDGROSSWGT ) as ''GrossWgtQtyReceivedPC''
 ,case when PA.CaseCnt>0 then  ( ( ( RD.QtyReceived )) * S.STDGROSSWGT)  / PA.CaseCnt else 0 end as ''GrossWgtQtyReceivedCS''
 , ( RD.QtyReceived*S.STDCUBE )as ''CBM-PC''
 ,case when PA.CaseCnt>0 then  ( ( RD.QtyReceived*S.STDCUBE )) / PA.CaseCnt else 0 end as ''CBM-CS''  
 ,S.SUSR3
 ,R.FinalizeDate
 ,S.itemclass
 ,S.Price              as ''Unit Cost''
 ,(S.Price) * ( ( RD.QtyReceived )) as ''Total Cost'' 
 , RD.BeforeReceivedQty as ''BeforeReceivedQty'' 
 , R.ContainerKey 
 , R.TrackingNo
 , RD.Externlineno --added 2/21/2023 crisnah
 , ST.SUSR1 [STORER_SUSR1]
 , ST.SUSR2 [STORER_SUSR2]
 , ST.SUSR3 [STORER_SUSR3]
 , ST.SUSR4 [STORER_SUSR4]
 , ST.SUSR5 [STORER_SUSR5]
 , L.LocationRoom, PA.PalletTi, PA.PalletHi
 '
 set @Stmt = @Stmt+'
 FROM BI.V_RECEIPT R WITH (NOLOCK)
 JOIN BI.V_RECEIPTDETAIL RD WITH (NOLOCK) ON (R.ReceiptKey=RD.ReceiptKey)
 JOIN BI.V_PACK PA WITH (NOLOCK) ON (PA.PackKey=RD.PackKey)
 JOIN BI.V_SKU S WITH (NOLOCK) ON (S.Sku=RD.Sku AND S.STORERKEY='''+@Param_Generic_Storerkey+''')
 LEFT OUTER JOIN BI.V_CODELKUP CO WITH (NOLOCK) ON (S.SUSR3 = CO.CODE AND (CO.LISTNAME=''PRINCIPAL'' or CO.LISTNAME IS NULL))
 LEFT JOIN BI.V_STORER ST WITH (NOLOCK) ON (R.CARRIERKEY=ST.STORERKEY)
 JOIN BI.V_LOC L WITH (NOLOCK) ON (RD.TOLOC=L.LOC AND R.FACILITY=L.FACILITY)
 WHERE 
R.StorerKey= '''+@Param_Generic_Storerkey+'''
AND R.FACILITY= '''+@PARAM_GENERIC_FACILITY+'''
AND R.'+@Param_Generic_DateDataType+'  >= '''+convert(nvarchar(19),@Param_Generic_StartDate,121)+'''
AND R.'+@Param_Generic_DateDataType+'  <='''+convert(nvarchar(19),@Param_Generic_EndDate,121)+'''  
AND R.STATUS IN ('+@Param_Receipt_Status+') '

 set @Stmt = @Stmt+'
 GROUP BY R.StorerKey, R.Facility,R.DocType, R.ReceiptKey, R.ExternReceiptKey, R.ReceiptGroup, R.ReceiptDate, R.POKey, 
 R.CarrierKey, R.CarrierName, R.CarrierAddress1, R.CarrierAddress2, R.CarrierCity, R.CarrierState, R.CarrierReference, 
 R.WarehouseReference, R.OriginCountry, R.VehicleNumber, R.VehicleDate, R.PlaceOfLoading, R.PlaceOfDischarge, R.PlaceofDelivery, 
 R.IncoTerms, R.TermsNote, R.ContainerKey, R.ContainerType, R.Signatory, R.PlaceofIssue, R.OpenQty,R.Status, R.ASNStatus,
	R.Notes, R.EffectiveDate, R.AddDate, R.AddWho, R.RECType, R.ASNReason, R.UserDefine01, R.UserDefine02, 
	R.UserDefine03, R.UserDefine04, R.UserDefine05, R.UserDefine06, R.UserDefine07, R.UserDefine08, R.UserDefine09, R.UserDefine10, 
	R.FinalizeDate, R.SellerName, R.SellerCompany, R.SellerAddress1, R.SellerAddress2, R.SellerCity, R.Appointment_No, RD.POKey, 
	RD.ExternPoKey, RD.POLineNumber, RD.ReceiptLineNumber, RD.Sku, S.DESCR, RD.UOM, RD.PackKey, PA.PackUOM3, PA.Qty, PA.PackUOM2, 
	PA.InnerPack, PA.PackUOM1, PA.CaseCnt, RD.PutawayLoc, RD.ToLoc, RD.ToId, RD.Lottable01, RD.Lottable02, RD.Lottable03, RD.Lottable04, 
	RD.Lottable05, RD.Lottable06, RD.Lottable07, RD.Lottable08, RD.Lottable09, RD.Lottable10, RD.Lottable11, RD.Lottable12, RD.Lottable13, 
	RD.Lottable14, RD.Lottable15, RD.UserDefine01, RD.UserDefine02, RD.UserDefine03, RD.UserDefine04, RD.UserDefine05, RD.UserDefine06, 
	RD.UserDefine07, RD.UserDefine08, RD.UserDefine09, RD.UserDefine10, S.STDNETWGT, S.STDGROSSWGT, S.SUSR3, R.FinalizeDate, 
	S.itemclass, S.Price ,RD.BeforeReceivedQty ,RD.QtyExpected, rd.QtyReceived, s.STDCUBE
	 , R.ContainerKey 
    , R.TrackingNo , RD.Externlineno
    , ST.SUSR1
	 , ST.SUSR2
	 , ST.SUSR3
	 , ST.SUSR4
	 , ST.SUSR5 ,R.Sellerphone1,R.Sellerphone2, L.LocationRoom, PA.PalletTi, PA.PalletHi
	ORDER BY  R.ReceiptKey
	'
	IF @nDebug = 1 
	  BEGIN
	  PRINT @Stmt
      PRINT SUBSTRING(@Stmt, 4001, 8000)
      PRINT SUBSTRING(@Stmt, 8001,12000)  
      PRINT SUBSTRING(@Stmt, 12001,16000)  

	  END

  EXEC sp_ExecuteSql @Stmt;
   SET @nRowCnt = @@ROWCOUNT
   SET @cParamOut = '{ "Stmt": "'+@Stmt+'" }';

   
   UPDATE dbo.ExecutionLog SET TimeEnd = GETDATE(), RowCnt = @nRowCnt, ParamOut = @cParamOut WHERE LogId = (SELECT TOP 1 LogId FROM @tVarLogId);

END

GO