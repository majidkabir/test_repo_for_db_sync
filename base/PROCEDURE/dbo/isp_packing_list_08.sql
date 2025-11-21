SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/******************************************************************************/            
/* Store Procedure: isp_Packing_List_08                                       */            
/* Creation Date:                                                             */            
/* Copyright: IDS                                                             */            
/* Written by: NJOW                                                           */            
/*                                                                            */            
/* Purpose: Generate Packing Slip                                             */            
/*                                                                            */            
/* Called By:                                                                 */            
/*                                                                            */            
/* PVCS Version: 1.0                                                          */            
/*                                                                            */            
/* Version: 5.4                                                               */            
/*                                                                            */            
/* Data Modifications:                                                        */            
/*                                                                            */            
/* Updates:                                                                   */            
/* Date         Author    Ver.  Purposes                                      */          
/* 29-Dec-2011  James     1.1   Bug fix (james01)                             */          
/* 31-Dec-2011  ChewKP    1.2   Fixes on Grouping and Mapping (ChewKP01)      */        
/* 10-01-2012   ChewKP    1.3   Standardize ConsoOrderKey Mapping             */      
/*                              (ChewKP02)                                    */      
/* 28-01-2012   Shong     1.4   Support 4 Size Grouping for Pack List         */   
/* 01-03-2012   Chee      1.5   Change MBOL.CarrierKey=ORDERS.UserDefine02,   */  
/*                              MBOL.UserDefine07=ORDERS.DeliveryDate(Chee01) */   
/******************************************************************************/            
           
CREATE PROC [dbo].[isp_Packing_List_08]           
  (@c_PickSlipNo NVARCHAR(10))            
AS          
BEGIN          
   SET NOCOUNT ON          
   SET ANSI_WARNINGS OFF          
   SET QUOTED_IDENTIFIER OFF          
   SET CONCAT_NULL_YIELDS_NULL OFF            
    
   DECLARE         
      @c_Size01   NVARCHAR(5),     
      @c_Size02   NVARCHAR(5),     
      @c_Size03   NVARCHAR(5),     
      @c_Size04   NVARCHAR(5),     
      @c_Size05   NVARCHAR(5),     
      @c_Size06   NVARCHAR(5),     
      @c_Size07   NVARCHAR(5),     
      @c_Size08   NVARCHAR(5),     
      @c_Size09   NVARCHAR(5),     
      @c_Size10   NVARCHAR(5),     
      @c_Size11   NVARCHAR(5),     
      @c_Size12   NVARCHAR(5)     
                   
   DECLARE @n_ID int          
          ,@c_Size NVARCHAR(5)          
          ,@c_Size01a NVARCHAR(5)          
          ,@c_Size02a NVARCHAR(5)                   
          ,@c_Size03a NVARCHAR(5)                   
          ,@c_Size04a NVARCHAR(5)                   
          ,@c_Size05a NVARCHAR(5)                   
          ,@c_Size06a NVARCHAR(5)                   
          ,@c_Size07a NVARCHAR(5)                   
          ,@c_Size08a NVARCHAR(5)                   
          ,@c_Size09a NVARCHAR(5)                   
          ,@c_Size10a NVARCHAR(5)                   
          ,@c_Size11a NVARCHAR(5)                   
          ,@c_Size12a NVARCHAR(5)     
          ,@c_Size01b NVARCHAR(5)          
          ,@c_Size02b NVARCHAR(5)                   
          ,@c_Size03b NVARCHAR(5)                   
          ,@c_Size04b NVARCHAR(5)                   
          ,@c_Size05b NVARCHAR(5)                   
          ,@c_Size06b NVARCHAR(5)                   
          ,@c_Size07b NVARCHAR(5)                   
          ,@c_Size08b NVARCHAR(5)                   
          ,@c_Size09b NVARCHAR(5)                   
          ,@c_Size10b NVARCHAR(5)                   
          ,@c_Size11b NVARCHAR(5)                   
          ,@c_Size12b NVARCHAR(5)    
          ,@c_Size01c NVARCHAR(5)          
          ,@c_Size02c NVARCHAR(5)                   
          ,@c_Size03c NVARCHAR(5)                   
          ,@c_Size04c NVARCHAR(5)                   
          ,@c_Size05c NVARCHAR(5)                   
          ,@c_Size06c NVARCHAR(5)                   
          ,@c_Size07c NVARCHAR(5)                   
          ,@c_Size08c NVARCHAR(5)                   
          ,@c_Size09c NVARCHAR(5)                   
          ,@c_Size10c NVARCHAR(5)                   
          ,@c_Size11c NVARCHAR(5)                   
          ,@c_Size12c NVARCHAR(5)    
          ,@c_Size01d NVARCHAR(5)          
          ,@c_Size02d NVARCHAR(5)                   
          ,@c_Size03d NVARCHAR(5)                 
          ,@c_Size04d NVARCHAR(5)                   
          ,@c_Size05d NVARCHAR(5)                   
          ,@c_Size06d NVARCHAR(5)                   
          ,@c_Size07d NVARCHAR(5)                   
          ,@c_Size08d NVARCHAR(5)                   
          ,@c_Size09d NVARCHAR(5)                   
          ,@c_Size10d NVARCHAR(5)                   
          ,@c_Size11d NVARCHAR(5)                   
          ,@c_Size12d NVARCHAR(5)    
                                                         
   DECLARE @c_Style     NVARCHAR(20),     
           @c_BUSR8     NVARCHAR(30),     
           @n_Index       INT,
           @f_TotalWeight FLOAT,
           @n_TotalCtns   INT 

   SET @f_TotalWeight = 0
   SELECT @f_TotalWeight = SUM(ISNULL(pi1.[Weight],0))
   FROM PackInfo pi1 WITH (NOLOCK)
   WHERE pi1.PickSlipNo = @c_PickSlipNo
   
   IF @f_TotalWeight = 0
   BEGIN
      SELECT @f_TotalWeight = 
            SUM(PD.Qty * ISNULL(S.StdGrossWgt,0)) 
      FROM PACKDETAIL PD (NOLOCK)       
      JOIN SKU S (NOLOCK) ON PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku       
      WHERE PD.Pickslipno = @c_PickSlipNo   	
   END
    
   SET @n_TotalCtns = 0 
   
   SELECT @n_TotalCtns = COUNT(DISTINCT PD.Labelno) 
   FROM PACKDETAIL PD (NOLOCK) 
   WHERE PD.Pickslipno = @c_PickSlipNo 
   
   IF OBJECT_ID('tempdb..#TempSizeGroup') IS NOT NULL     
      DROP TABLE #TempSizeGroup    
          
   CREATE TABLE #TempSizeGroup (    
      Style    NVARCHAR(20),    
      SizeGrp  NVARCHAR(1),      
      Size01   NVARCHAR(5),     
      Size02   NVARCHAR(5),     
      Size03   NVARCHAR(5),     
      Size04   NVARCHAR(5),     
      Size05   NVARCHAR(5),     
      Size06   NVARCHAR(5),     
      Size07   NVARCHAR(5),     
      Size08   NVARCHAR(5),     
      Size09   NVARCHAR(5),     
      Size10   NVARCHAR(5),     
      Size11   NVARCHAR(5),     
      Size12   NVARCHAR(5))    
                
   DECLARE CUR_StyleSize CURSOR LOCAL FAST_FORWARD READ_ONLY FOR    
   SELECT SKU.Style, ISNULL(SKU.[Size],''), MIN(ISNULL(SKU.BUSR8,''))     
   FROM PACKHEADER (NOLOCK)          
   JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno          
   JOIN SKU (NOLOCK) ON PACKHEADER.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku          
   WHERE PACKHEADER.Pickslipno = @c_Pickslipno      
   GROUP BY Style, ISNULL(SKU.[Size],'')     
   ORDER BY Style, MIN(ISNULL(SKU.BUSR8,''))    
             
   OPEN CUR_StyleSize     
    
   SET @n_Index = 1    
   FETCH NEXT FROM CUR_StyleSize INTO @c_Style, @c_Size, @c_BUSR8    
   WHILE @@FETCH_STATUS <> -1    
   BEGIN    
      IF NOT EXISTS(SELECT 1 FROM #TempSizeGroup WHERE Style = @c_Style)    
      BEGIN    
       INSERT INTO #TempSizeGroup(Style, SizeGrp, Size01, Size02, Size03, Size04, Size05,    
                   Size06, Size07, Size08, Size09, Size10, Size11, Size12)    
       VALUES(@c_Style, '', @c_Size, '','','','','','','','','','','')       
       SET @n_Index = 1             
      END    
      ELSE    
      BEGIN    
         UPDATE #TempSizeGroup     
            SET Size02 = CASE WHEN @n_Index = 2  THEN @c_Size ELSE Size02 END,    
                Size03 = CASE WHEN @n_Index = 3  THEN @c_Size ELSE Size03 END,    
                Size04 = CASE WHEN @n_Index = 4  THEN @c_Size ELSE Size04 END,    
                Size05 = CASE WHEN @n_Index = 5  THEN @c_Size ELSE Size05 END,    
                Size06 = CASE WHEN @n_Index = 6  THEN @c_Size ELSE Size06 END,    
                Size07 = CASE WHEN @n_Index = 7  THEN @c_Size ELSE Size07 END,    
                Size08 = CASE WHEN @n_Index = 8  THEN @c_Size ELSE Size08 END,    
                Size09 = CASE WHEN @n_Index = 9  THEN @c_Size ELSE Size09 END,    
                Size10 = CASE WHEN @n_Index = 10 THEN @c_Size ELSE Size10 END,    
                Size11 = CASE WHEN @n_Index = 11 THEN @c_Size ELSE Size11 END,    
                Size12 = CASE WHEN @n_Index = 12 THEN @c_Size ELSE Size12 END    
         WHERE Style = @c_Style    
      END    
           
      SET @n_Index = @n_Index + 1     
    FETCH NEXT FROM CUR_StyleSize INTO @c_Style, @c_Size, @c_BUSR8    
   END    
   CLOSE CUR_StyleSize    
      
   SET @c_Size01A = ''    
   SET @c_Size02A = ''    
   SET @c_Size03A = ''    
   SET @c_Size04A = ''    
   SET @c_Size05A = ''    
   SET @c_Size06A = ''    
   SET @c_Size07A = ''    
   SET @c_Size08A = ''    
   SET @c_Size09A = ''    
   SET @c_Size10A = ''    
   SET @c_Size11A = ''    
   SET @c_Size12A = ''    
   SET @c_Size01B = ''    
   SET @c_Size02B = ''    
   SET @c_Size03B = ''    
   SET @c_Size04B = ''    
   SET @c_Size05B = ''    
   SET @c_Size06B = ''    
   SET @c_Size07B = ''    
   SET @c_Size08B = ''    
   SET @c_Size09B = ''    
   SET @c_Size10B = ''    
   SET @c_Size11B = ''    
   SET @c_Size12B = ''    
   SET @c_Size01C = ''    
   SET @c_Size02C = ''    
   SET @c_Size03C = ''    
   SET @c_Size04C = ''    
   SET @c_Size05C = ''    
   SET @c_Size06C = ''    
   SET @c_Size07C = ''    
   SET @c_Size08C = ''    
   SET @c_Size09C = ''    
   SET @c_Size10C = ''    
   SET @c_Size11C = ''    
   SET @c_Size12C = ''    
   SET @c_Size01D = ''    
   SET @c_Size02D = ''    
   SET @c_Size03D = ''    
   SET @c_Size04D = ''    
   SET @c_Size05D = ''    
   SET @c_Size06D = ''    
   SET @c_Size07D = ''    
   SET @c_Size08D = ''    
   SET @c_Size09D = ''    
   SET @c_Size10D = ''    
   SET @c_Size11D = ''    
   SET @c_Size12D = ''    
    
   SET @n_Index = 1    
   WHILE 1=1    
   BEGIN    
      SELECT TOP 1     
      @c_Size01 = Size01,     
      @c_Size02 = Size02,     
      @c_Size03 = Size03,     
      @c_Size04 = Size04,     
      @c_Size05 = Size05,     
      @c_Size06 = Size06,     
      @c_Size07 = Size07,     
      @c_Size08 = Size08,    
      @c_Size09 = Size09,     
      @c_Size10 = Size10,     
      @c_Size11 = Size11,     
      @c_Size12 = Size12    
        FROM #TempSizeGroup    
      WHERE SizeGrp = ''    
    
    IF @@ROWCOUNT = 0    
       BREAK    
                  
      UPDATE T    
      SET SizeGrp = CASE WHEN @n_Index = 1 THEN 'A'    
                         WHEN @n_Index = 2 THEN 'B'    
                         WHEN @n_Index = 3 THEN 'C'    
                         WHEN @n_Index = 4 THEN 'D'    
                         WHEN @n_Index = 5 THEN 'E'    
                         WHEN @n_Index = 6 THEN 'F'    
                         WHEN @n_Index = 7 THEN 'G'    
                         WHEN @n_Index = 8 THEN 'H'    
                         WHEN @n_Index = 9 THEN 'I'    
                         ELSE 'Z'    
                    END     
      FROM #TempSizeGroup T     
      WHERE SizeGrp = '' AND    
      Size01 = @c_Size01 AND     
      Size02 = @c_Size02 AND     
      Size03 = @c_Size03 AND     
      Size04 = @c_Size04 AND     
      Size05 = @c_Size05 AND     
      Size06 = @c_Size06 AND     
      Size07 = @c_Size07 AND     
      Size08 = @c_Size08 AND    
      Size09 = @c_Size09 AND     
      Size10 = @c_Size10 AND     
      Size11 = @c_Size11 AND     
      Size12 = @c_Size12    
          
      IF @n_Index = 1     
      BEGIN    
         SET @c_Size01a = @c_Size01    
         SET @c_Size02a = @c_Size02    
         SET @c_Size03a = @c_Size03    
         SET @c_Size04a = @c_Size04    
         SET @c_Size05a = @c_Size05    
         SET @c_Size06a = @c_Size06    
         SET @c_Size07a = @c_Size07    
         SET @c_Size08a = @c_Size08    
         SET @c_Size09a = @c_Size09    
         SET @c_Size10a = @c_Size10    
         SET @c_Size11a = @c_Size11    
         SET @c_Size12a = @c_Size12    
      END    
      IF @n_Index = 2     
      BEGIN    
         SET @c_Size01b = @c_Size01    
         SET @c_Size02b = @c_Size02    
         SET @c_Size03b = @c_Size03    
         SET @c_Size04b = @c_Size04    
         SET @c_Size05b = @c_Size05    
         SET @c_Size06b = @c_Size06    
         SET @c_Size07b = @c_Size07    
         SET @c_Size08b = @c_Size08    
         SET @c_Size09b = @c_Size09    
         SET @c_Size10b = @c_Size10    
         SET @c_Size11b = @c_Size11    
         SET @c_Size12b = @c_Size12    
      END    
      IF @n_Index = 3     
      BEGIN    
         SET @c_Size01c = @c_Size01    
         SET @c_Size02c = @c_Size02    
         SET @c_Size03c = @c_Size03    
         SET @c_Size04c = @c_Size04    
         SET @c_Size05c = @c_Size05    
         SET @c_Size06c = @c_Size06    
         SET @c_Size07c = @c_Size07    
         SET @c_Size08c = @c_Size08    
         SET @c_Size09c = @c_Size09    
         SET @c_Size10c = @c_Size10    
         SET @c_Size11c = @c_Size11    
         SET @c_Size12c = @c_Size12    
      END    
      IF @n_Index = 4     
      BEGIN    
         SET @c_Size01d = @c_Size01    
         SET @c_Size02d = @c_Size02    
         SET @c_Size03d = @c_Size03    
         SET @c_Size04d = @c_Size04    
         SET @c_Size05d = @c_Size05    
         SET @c_Size06d = @c_Size06    
         SET @c_Size07d = @c_Size07    
         SET @c_Size08d = @c_Size08    
         SET @c_Size09d = @c_Size09    
         SET @c_Size10d = @c_Size10    
         SET @c_Size11d = @c_Size11    
         SET @c_Size12d = @c_Size12    
      END                      
           
    SET @n_Index = @n_Index + 1     
   END    
       
   --SELECT * FROM #TempSizeGroup    
          
   SELECT TOP 1          
          ORDERS.Storerkey,          
          ORDERS.Facility,          
          --ORDERS.MBOLKey,      -- (Chee01)  
          ORDERS.UserDefine02,   -- (Chee01)  
          ORDERS.DeliveryDate,   -- (Chee01)  
          ORDERS.Consigneekey,          
          ORDERS.C_Company,          
          ORDERS.C_Address1,          
          ORDERS.C_Address2,          
          ORDERS.C_Address3,          
          ORDERS.C_Address4,          
          ORDERS.C_City,          
          ORDERS.C_State,          
          ORDERS.C_Zip,          
          ORDERS.C_Country,          
          ORDERS.BuyerPO,          
          ORDERS.Intermodalvehicle,          
          ORDERS.Userdefine03,          
          ORDERS.Markforkey,          
          SUBSTRING(CONVERT(NVARCHAR(500),ORDERS.Notes2),1,250) AS Notes,          
          SUBSTRING(CONVERT(NVARCHAR(500),ORDERS.Notes2),251,500) AS Notes2,          
          ORDERDETAIL.ConsoOrderKey,                    
          ORDERDETAIL.ExternConsoOrderKey,     
          ORDERS.UpdateSource             
   INTO #Temp_Orders          
   FROM PACKHEADER WITH (NOLOCK)          
   --JOIN ORDERDETAIL WITH (NOLOCK) ON (PACKHEADER.Consigneekey= ORDERDETAIL.ConsoOrderkey)    --(ChewKP02)      
   JOIN ORDERDETAIL WITH (NOLOCK) ON (PACKHEADER.ConsoOrderKey= ORDERDETAIL.ConsoOrderkey)    --(ChewKP02)      
   JOIN ORDERS WITH (NOLOCK) ON (ORDERS.Orderkey= ORDERDETAIL.Orderkey)          
   WHERE PACKHEADER.PickslipNo = @c_Pickslipno            
    
   SELECT PACKHEADER.Pickslipno,          
          STORER.Company As Address1,          
          STORER.Address1 As Address2,          
          STORER.Address3,          
          STORER.Address4,          
          STORER.City,          
          STORER.State,          
          STORER.Zip,          
          STORER.Country,          
          ST2.Company    AS Shipfrom1,          
          FACILITY.Descr AS Shipfrom2,          
          FACILITY.Userdefine01 AS Shipfrom3,          
          RTRIM(FACILITY.Userdefine03) + '      ' + RTRIM(FACILITY.Userdefine04) AS Shipfrom4,          
          MAX(ISNULL(SKU.Susr1,'')) AS Division,          
          ORDERS.Consigneekey,          
          ORDERS.C_Company,          
          ORDERS.C_Address1,          
          ORDERS.C_Address2,          
          ORDERS.C_Address3,          
          ORDERS.C_Address4,          
          ORDERS.C_City,          
    ORDERS.C_State,          
          ORDERS.C_Zip,          
          ORDERS.C_Country,          
          PACKHEADER.Editdate AS InvoiceDate,          
          ORDERS.BuyerPO AS InvoiceNo,          
          ORDERS.Intermodalvehicle AS CustAC,          
          --ORDERS.ExternOrderkey AS PO,          
          ORDERS.ExternConsoOrderKey AS PO,          
          ORDERS.Userdefine03 AS Custdept,          
          SCAC.Susr5 AS SCACCode,          
          SCAC.Company AS SCACName,          
          ORDERS.Markforkey AS CustDoor,          
          ISNULL(SKU.Size,'') AS Size,          
          ISNULL(SKU.Style,'') AS Style,          
          ISNULL(SKU.Color,'') AS Color,          
          ISNULL(SKU.Measurement,'') AS Measurement,          
          ISNULL(SKU.LotxIdDetailOtherlabel2,'') AS Colordesc,          
          ISNULL(SKU.Busr1,'') AS Busr1,          
          SUM(PACKDETAIL.Qty) AS SizeQty,          
          SUBSTRING(CONVERT(NVARCHAR(500),ORDERS.Notes2),1,250) AS Notes,          
          SUBSTRING(CONVERT(NVARCHAR(500),ORDERS.Notes2),251,500) AS Notes2,          
          --MBOL.Userdefine07 AS ShipDate,   -- (Chee01)  
          ORDERS.DeliveryDate As ShipDate,   -- (Chee01)       
         (SELECT COUNT(DISTINCT ISNULL(S.Style,'')) FROM PACKDETAIL PD (NOLOCK)           
           JOIN SKU S (NOLOCK) ON PD.Storerkey = S.Storerkey AND PD.Sku = S.Sku          
           WHERE PD.Pickslipno = PACKHEADER.Pickslipno) AS TotalStyle,                     
          @n_TotalCtns   AS TotalCarton,      
          @f_TotalWeight AS TotalCtnWeight,   
          @c_Size01a AS Size01A,          
          @c_Size02a AS Size02A,          
          @c_Size03a AS Size03A,          
          @c_Size04a AS Size04A,          
          @c_Size05a AS Size05A,          
          @c_Size06a AS Size06A,          
          @c_Size07a AS Size07A,          
          @c_Size08a AS Size08A,          
          @c_Size09a AS Size09A,          
          @c_Size10a AS Size10A,          
          @c_Size11a AS Size11A,          
          @c_Size12a AS Size12A,     
          @c_Size01b AS Size01B,          
          @c_Size02b AS Size02B,          
          @c_Size03b AS Size03B,          
          @c_Size04b AS Size04B,          
          @c_Size05b AS Size05B,          
          @c_Size06b AS Size06B,          
          @c_Size07b AS Size07B,          
          @c_Size08b AS Size08B,          
          @c_Size09b AS Size09B,          
          @c_Size10b AS Size10B,          
          @c_Size11b AS Size11B,          
          @c_Size12b AS Size12B,     
          @c_Size01c AS Size01C,          
          @c_Size02c AS Size02C,          
          @c_Size03c AS Size03C,          
          @c_Size04c AS Size04C,          
          @c_Size05c AS Size05C,          
          @c_Size06c AS Size06C,          
          @c_Size07c AS Size07C,          
          @c_Size08c AS Size08C,          
          @c_Size09c AS Size09C,          
          @c_Size10c AS Size10C,          
          @c_Size11c AS Size11C,          
          @c_Size12c AS Size12C,     
          @c_Size01d AS Size01D,          
          @c_Size02d AS Size02D,          
          @c_Size03d AS Size03D,          
          @c_Size04d AS Size04D,          
          @c_Size05d AS Size05D,          
          @c_Size06d AS Size06D,          
          @c_Size07d AS Size07D,          
          @c_Size08d AS Size08D,          
          @c_Size09d AS Size09D,          
          @c_Size10d AS Size10D,          
          @c_Size11d AS Size11D,          
          @c_Size12d AS Size12D,                                        
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size01 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty1,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size02 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty2,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size03 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty3,          
          SUM(CASE WHEN ISNULL(SKU.Size,'') = SG.Size04 AND ISNULL(SKU.Style,'') = SG.Style THEN PACKDETAIL.Qty ELSE 0 END) AS SizeQty4,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size05 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty5,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size06 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty6,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size07 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty7,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size08 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty8,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size09 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty9,          
   CASE WHEN ISNULL(SKU.Size,'') = SG.Size10 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty10,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size11 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty11,          
          CASE WHEN ISNULL(SKU.Size,'') = SG.Size12 AND ISNULL(SKU.Style,'') = SG.Style THEN SUM(PACKDETAIL.Qty) ELSE 0 END AS SizeQty12,     
          SG.SizeGrp           
   INTO #TMP_PACKDETAIL          
   FROM PACKHEADER (NOLOCK)          
   JOIN PACKDETAIL (NOLOCK) ON PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno          
   JOIN #Temp_Orders ORDERS ON (PACKHEADER.ConsoOrderKey = ORDERS.ConsoOrderKey)  -- (ChewKP02)           
   LEFT OUTER JOIN STORER (NOLOCK) ON ORDERS.UpdateSource = STORER.Storerkey          
   JOIN FACILITY (NOLOCK) ON ORDERS.Facility = FACILITY.Facility          
--   JOIN MBOL (NOLOCK) ON ORDERS.Mbolkey = MBOL.Mbolkey                   -- (Chee01)                    
--   LEFT JOIN STORER SCAC (NOLOCK) ON MBOL.Carrierkey = SCAC.Storerkey    -- (Chee01)    
   LEFT JOIN STORER SCAC (NOLOCK) ON ORDERS.UserDefine02 = SCAC.Storerkey  -- (Chee01)   
   JOIN SKU (NOLOCK) ON PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku       
   JOIN #TempSizeGroup SG ON SG.Style = SKU.Style           
   JOIN STORER ST2 WITH (NOLOCK) ON ST2.StorerKey = ORDERS.StorerKey     
   WHERE PACKHEADER.Pickslipno = @c_Pickslipno     
   GROUP BY          
          STORER.Company,          
          STORER.Address1,          
          STORER.Address3,          
          STORER.Address4,          
          STORER.City,          
          STORER.State,          
          STORER.Zip,          
          STORER.Country,          
          ST2.Company,          
          FACILITY.Descr,          
          FACILITY.Userdefine01,          
          RTRIM(FACILITY.Userdefine03) + '      ' + RTRIM(FACILITY.Userdefine04),          
          ORDERS.Consigneekey,          
          ORDERS.C_Company,          
          ORDERS.C_Address1,          
          ORDERS.C_Address2,          
          ORDERS.C_Address3,          
          ORDERS.C_Address4,          
          ORDERS.C_City,          
          ORDERS.C_State,          
          ORDERS.C_Zip,          
          ORDERS.C_Country,          
          PACKHEADER.Editdate,          
          ORDERS.BuyerPO,          
          ORDERS.Intermodalvehicle,          
          ORDERS.ExternConsoOrderKey,          
          ORDERS.Userdefine03,          
          SCAC.Susr5,          
          SCAC.Company,          
          ORDERS.Markforkey,          
          ISNULL(SKU.Size,''),          
          ISNULL(SKU.Style,''),          
          ISNULL(SKU.Color,''),          
          ISNULL(SKU.Measurement,''),          
          ISNULL(SKU.LotxIdDetailOtherlabel2,''),          
          ISNULL(SKU.Busr1,''),                      
          SUBSTRING(CONVERT(NVARCHAR(500),ORDERS.Notes2),1,250),          
          SUBSTRING(CONVERT(NVARCHAR(500),ORDERS.Notes2),251,500),                      
          --MBOL.Userdefine07,   -- (Chee01)   
          ORDERS.DeliveryDate,   -- (Chee01)      
          PACKHEADER.Pickslipno,     
          SG.Size01,     
          SG.Size02,     
          SG.Size03,     
          SG.Size04,     
          SG.Size05,     
          SG.Size06,     
          SG.Size07,     
          SG.Size08,     
          SG.Size09,     
          SG.Size10,     
          SG.Size11,     
          SG.Size12,    
          SG.SizeGrp,     
          SG.Style     
                   
              
   SELECT Pickslipno,          
          Address1,          
          Address2,          
          Address3,          
          Address4,          
          City,          
          State,          
          Zip,          
          Country,          
          Shipfrom1,          
          Shipfrom2,          
          Shipfrom3,          
          Shipfrom4,          
          Division,          
          Consigneekey,          
          C_Company,          
          C_Address1,          
          C_Address2,          
          C_Address3,          
          C_Address4,          
          C_City,          
          C_State,          
          C_Zip,          
          C_Country,          
          InvoiceDate,          
          InvoiceNo,          
          CustAC,          
          PO,          
          Custdept,          
          SCACCode,          
          SCACName,          
          CustDoor,          
          Style,          
          Color,          
          Measurement,          
          ColorDesc,          
          Busr1,          
          Notes,          
          Notes2,          
          ShipDate,          
          TotalCarton,          
          TotalStyle,          
          TotalCtnWeight,          
          Size01A,          
          Size02A,          
          Size03A,          
          Size04A,          
          Size05A,          
          Size06A,          
          Size07A,          
          Size08A,          
          Size09A,          
          Size10A,          
          Size11A,          
          Size12A,    
          Size01B,          
          Size02B,          
          Size03B,          
          Size04B,          
          Size05B,          
          Size06B,          
          Size07B,          
          Size08B,          
          Size09B,          
          Size10B,          
          Size11B,          
          Size12B,          
          Size01C,          
          Size02C,          
          Size03C,          
          Size04C,          
          Size05C,          
          Size06C,          
          Size07C,          
          Size08C,          
          Size09C,          
          Size10C,          
          Size11C,          
          Size12C,          
          Size01D,          
          Size02D,          
          Size03D,          
          Size04D,          
          Size05D,          
          Size06D,          
          Size07D,          
          Size08D,          
          Size09D,          
          Size10D,          
          Size11D,          
          Size12D,          
          SUM(SizeQty1)  AS SizeQty1,          
          SUM(SizeQty2)  AS SizeQty2,          
          SUM(SizeQty3)  AS SizeQty3,          
          SUM(SizeQty4)  AS SizeQty4,          
          SUM(SizeQty5)  AS SizeQty5,          
          SUM(SizeQty6)  AS SizeQty6,          
          SUM(SizeQty7)  AS SizeQty7,          
          SUM(SizeQty8)  AS SizeQty8,          
          SUM(SizeQty9)  AS SizeQty9,          
          SUM(SizeQty10) AS SizeQty10,          
          SUM(SizeQty11) AS SizeQty11,          
          SUM(SizeQty12) AS SizeQty12,          
          SUM(SizeQty) AS TotalQty,     
          SizeGrp         
   FROM #TMP_PACKDETAIL          
   GROUP BY Pickslipno,      
            Address1,                
            Address2,                
            Address3,                
            Address4,                
            City,                    
            State,                   
            Zip,                     
            Country,                 
            Shipfrom1,               
            Shipfrom2,               
            Shipfrom3,               
            Shipfrom4,               
            Division,                
            Consigneekey,            
            C_Company,               
            C_Address1,              
            C_Address2,              
            C_Address3,              
            C_Address4,              
            C_City,                  
            C_State,                 
            C_Zip,                   
            C_Country,              
            InvoiceDate,           
            InvoiceNo,               
            CustAC,                  
            PO,                      
            Custdept,                
            SCACCode,                
            SCACName,                
            CustDoor,                
            Style,                   
            Color,                   
            Measurement,             
            ColorDesc,                    
            Busr1,                   
            Notes,          
            Notes2,                   
            ShipDate,                
            TotalCarton,             
            TotalStyle,          
            TotalCtnWeight,          
             Size01A,          
             Size02A,          
             Size03A,          
             Size04A,          
             Size05A,          
             Size06A,          
             Size07A,          
             Size08A,          
             Size09A,          
             Size10A,          
             Size11A,          
             Size12A,    
             Size01B,          
             Size02B,          
             Size03B,          
             Size04B,          
             Size05B,          
             Size06B,          
             Size07B,          
             Size08B,          
             Size09B,          
             Size10B,          
             Size11B,          
             Size12B,          
             Size01C,          
             Size02C,          
             Size03C,          
             Size04C,          
             Size05C,          
             Size06C,          
             Size07C,          
             Size08C,          
             Size09C,          
             Size10C,          
             Size11C,          
             Size12C,          
             Size01D,          
             Size02D,          
             Size03D,          
             Size04D,          
             Size05D,          
             Size06D,          
             Size07D,          
             Size08D,          
             Size09D,          
             Size10D,          
             Size11D,          
             Size12D,     
             SizeGrp          
                      
--For Testing---          
/*                 
   SELECT '0000000001',          
          'Address1WWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW.',          
          'Address2',          
          'Address3',          
          'Address4',          
          'City',          
          'State',          
          'Zip123',          
          'Country',          
          'Shipfrom1WWWWWWWWWWWWWWWWWWWW.',          
          'Shipfrom2',          
          'Shipfrom3',          
          'Shipfrom4',          
          'Div',          
          'Consigneekey',          
          'C_CompanyWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWWW.',          
          'C_Address1',          
          'C_Address2',          
          'C_Address3',          
          'C_Address4',          
          'C_City',          
          'C_State',          
          'C_Zip1',          
          'C_Country',          
          GetDate(),          
          'InvoiceNo12345.',          
          'CustAC12345678.',          
          'PO123456789012.',          
          'Custdept',          
          'SCACCode',          
          'SCACName',          
          'CustDoor',          
          'Style12345678.',          
          'Color',          
          'Measu',          
          'ColorDesc',          
          'Busr1-12345.',          
          'Notes NotesNotes Notes NotesNotes NotesNotes NotesNotes NotesNotes NotesNotes NotesNotes NotesNotes NotesNotes NotesNotes',          
          'Notes2 NotesNotesNotesNotesNotesNotesNotesNotesNotesNotes2',          
          getdate(),          
          999,          
          999,          
          99999.99,          
          'Size1',          
          'Size2',          
          'Size3',          
          'Size4',          
          'Size5',          
          'Size6',          
          'Size7',          
          'Size8',          
          'Size9',          
          'SizeA',          
          'SizeB',          
          'SizeC',          
          1000,          
          2000,          
          3000,          
          4000,          
          5000,          
          6000,          
          7000,          
          8000,          
          9000,          
          10000,          
          11000,          
          12000,          
          999999          
   FROM #TMP_PACKDETAIL          
   GROUP BY Pickslipno,              
            Address1,                
            Address2,                
            Address3,                
            Address4,                
            City,                    
            State,                   
            Zip,                     
            Country,                 
            Shipfrom1,               
            Shipfrom2,               
            Shipfrom3,               
            Shipfrom4,               
            Division,                
            Consigneekey,            
            C_Company,               
            C_Address1,              
            C_Address2,             
            C_Address3,              
            C_Address4,              
            C_City,                  
            C_State,                 
            C_Zip,                   
            C_Country,              
            InvoiceDate,           
            InvoiceNo,               
            CustAC,                  
            PO,                      
            Custdept,                
            SCACCode,                
            SCACName,                
            CustDoor,                
            Style,                   
            Color,                   
            Measurement,             
            ColorDesc,                    
     Busr1,                   
            Notes,                   
            Notes2,          
            ShipDate,                
            TotalCarton,             
            TotalStyle,          
            TotalCtnWeight,          
            Size1,                   
            Size2,                   
            Size3,                   
            Size4,                   
            Size5,                   
            Size6,                   
            Size7,                   
            Size8,                   
            Size9,                   
            Size10,                  
            Size11,                  
            Size12             
*/                        
          
END

GO