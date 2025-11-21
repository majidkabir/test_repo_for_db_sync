SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
 
 /************************************************************************/
 /* Store Procedure: isp_btb_partial_working_sheet                       */
 /* Creation Date: 18 SEP 2017                                           */
 /* Copyright: LF                                                        */
 /* Written by: CSCHONG                                                  */
 /*                                                                      */
 /* Purpose: WMS-2951-Logitech Ã»Back to Back Partial Working Sheet Report*/
 /*                                                                      */
 /* Called By:r_dw_btb_partial_working_sheet                             */
 /*                                                                      */
 /* PVCS Version: 1.1                                                    */
 /*                                                                      */
 /* Version: 5.4                                                         */
 /*                                                                      */
 /* Data Modifications:                                                  */
 /*                                                                      */
 /* Updates:                                                             */
 /* Date         Author    Ver.  Purposes                                */
 /* 05-Dec-2017  CSCHONG   1.1   WMS-3561-revise field logic (CS01)      */
 /* 15-JAN-2019  CSCHONG   1.3   WMS-3775 revised field logic (CS03)     */
 /************************************************************************/
 
 CREATE PROC [dbo].[isp_btb_partial_working_sheet] (@c_BTB_ShipmentKey NVARCHAR(10))
  AS
  BEGIN
    SET NOCOUNT ON 
    SET ANSI_NULLS OFF
    SET QUOTED_IDENTIFIER OFF 
    SET CONCAT_NULL_YIELDS_NULL OFF
    
 
     CREATE TABLE #btbWKSheet
        ( BTB_ShipmentKey     NVARCHAR(10),
          Sku                 NVARCHAR(20)  NULL, 
          DESCR               NVARCHAR(60) NULL,
          FromNo              NVARCHAR(40) NULL,
          PermitNo			  NVARCHAR(20) NULL,
          IssuedDate          DATETIME NULL,              
          QtyImport           INT,
          QtyShip             INT,
          QtyExported         INT,
          FTAQtyExport        INT,
          BTB_ShipmentListNo  NVARCHAR(10),
		  BalQty              INT)                        --CS03      
                                           
        INSERT INTO #btbWKSheet
             ( BTB_ShipmentKey, Sku, DESCR, FromNo,
              PermitNo, IssuedDate,  QtyImport,QtyShip,
              QtyExported,FTAQtyExport,BTB_ShipmentListNo,BalQty)                                    --CS01  --CS03   
  --CS03 Start			                           
 /*     SELECT BTB_SHP.BTB_ShipmentKey,BSD.Sku,BSD.SkuDescr,BSD.FormNo,BSD.PermitNo,BSD.IssuedDate,
             FTA.QtyImported,(FTA.QtyExported-BSD.QtyExported) as QtyShip,BSD.QtyExported,FTA.QtyExported      --CS01
             ,BSD.BTB_ShipmentListNo                                                                           --CS02 
		FROM BTB_SHIPMENT BTB_SHP WITH (NOLOCK)
		JOIN BTB_ShipmentDetail AS BSD WITH (NOLOCK) ON BSD.BTB_ShipmentKey=BTB_SHP.BTB_ShipmentKey
		JOIN BTB_FTA AS FTA WITH (NOLOCK) ON FTA.sku=BSD.Sku AND FTA.FormNo = BSD.FormNo
		WHERE BTB_SHP.BTB_ShipmentKey = @c_BTB_ShipmentKey
		ORDER BY BTB_SHP.BTB_ShipmentKey,BSD.BTB_ShipmentListNo,BSD.Sku
		*/
		
		Select BTB.BTB_ShipmentKey, BTB.Sku, BTB.SkuDescr, BTB.FormNo, BTB.PermitNo, BTB.IssuedDate, BTB.QtyImported,
		BTB.QtyShip, BTB.QtyExported,0, BTB.BTB_ShipmentListNo, 
		BalanceQuanity = (BTB.QtyImported - BTB.QtyShip - BTB.QtyExported)
		From
		(SELECT BTB_SHP.BTB_ShipmentKey,
		BSD.Sku,
		BSD.SkuDescr,
		BSD.FormNo,
		BSD.PermitNo,
		BSD.IssuedDate,
		FTA.QtyImported,
		QtyShip = (Select IsNull(Sum(BSD1.QtyExported), 0) From BTB_ShipmentDetail BSD1 with (nolock)
		Where BSD1.sku = BSD.Sku
		And BSD1.FormNo = BSD.FormNo
		And BSD1.BTB_ShipmentKey < BTB_SHP.BTB_ShipmentKey)
		+
		(Select IsNull(Sum(BSD2.QtyExported), 0) From BTB_ShipmentDetail BSD2 with (nolock)
		Where BSD2.sku = BSD.Sku
		And BSD2.FormNo = BSD.FormNo
		And BSD2.BTB_ShipmentKey = BTB_SHP.BTB_ShipmentKey
		And BSD2.BTB_ShipmentListNo = BSD2.BTB_ShipmentListNo
		And BSD2.BTB_ShipmentLineNo < BSD2.BTB_ShipmentLineNo)
		+ IsNull(( Select Top 1 IsNull(BSD3.QtyExported, 0) From BTB_ShipmentDetail BSD3 with (nolock)
		Where BSD3.BTB_ShipmentKey = BTB_SHP.BTB_ShipmentKey
		And BSD3.SKU = BSD.Sku
		And BSD3.FormNo = BSD.FormNo
		And BSD3.BTB_ShipmentListNo = BSD.BTB_ShipmentListNo
		And BSD3.BTB_ShipmentLineNo < BSD.BTB_ShipmentLineNo
		Order By BSD3.BTB_ShipmentLineNo Desc ), 0),
		BSD.QtyExported,
		BSD.BTB_ShipmentListNo --CS02 
		FROM BTB_SHIPMENT BTB_SHP WITH (NOLOCK)
		JOIN BTB_ShipmentDetail AS BSD WITH (NOLOCK) ON BSD.BTB_ShipmentKey=BTB_SHP.BTB_ShipmentKey
		JOIN BTB_FTA AS FTA WITH (NOLOCK) ON FTA.sku=BSD.Sku AND FTA.FormNo = BSD.FormNo
		WHERE BTB_SHP.BTB_ShipmentKey = @c_BTB_ShipmentKey ) BTB
		ORDER BY BTB_ShipmentKey, BTB.BTB_ShipmentListNo, BTB.Sku

 --CS03 End        
    
   GOTO SUCCESS
   FAILURE:
      DELETE FROM #btbWKSheet
   SUCCESS:
      SELECT * FROM #btbWKSheet  
    ORDER BY  BTB_ShipmentKey,BTB_ShipmentListNo,sku
      
      DROP Table #btbWKSheet  
  END

GO