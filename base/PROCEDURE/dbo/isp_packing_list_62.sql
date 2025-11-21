SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
   
/******************************************************************************/                
/* Store Procedure: isp_Packing_List_62                                       */                
/* Creation Date: 15-Mar-2019                                                 */                
/* Copyright: LFL                                                             */                
/* Written by: WLCHOOI                                                        */                
/*                                                                            */                
/* Purpose: WMS-8190 - Fabory Packing list                                    */    
/*                                                                            */                
/*                                                                            */                
/* Called By:  r_dw_packing_list_62                                           */                
/*                                                                            */                
/* GitLab Version: 1.4                                                        */                
/*                                                                            */                
/* Version: 1.0                                                               */                
/*                                                                            */                
/* Data Modifications:                                                        */                
/*                                                                            */                
/* Updates:                                                                   */                
/* Date         Author    Ver.  Purposes                                      */      
/*27-May-2019   WLCHOOI   1.0   Bug Fix & Performance Tunning (WL01)          */
/*19-Aug-2019   WLChooi   1.1   WMS-10210 - Add ReportCFG (WL02)              */
/*20-Nov-2019   WLChooi   1.2   WMS-11178 - Fixed qty issue when sku has      */
/*                              multiple lots (WL03)                          */
/*09-Jun-2020   WLChooi   1.3   Performance Tunning (WL04)                    */
/******************************************************************************/       
    
CREATE PROC [dbo].[isp_Packing_List_62]               
       (@c_MBOLKey NVARCHAR(20))                
AS              
BEGIN              
   SET NOCOUNT ON              
   SET ANSI_WARNINGS OFF              
   SET QUOTED_IDENTIFIER OFF              
   SET CONCAT_NULL_YIELDS_NULL OFF      
    
   DECLARE @n_continue        INT = 1
         , @c_orderkey        NVARCHAR(20) = ''
         , @n_sumqty          INT = 0 
         , @c_Lott07          NVARCHAR(40) = ''
         , @c_sku             NVARCHAR(40) = ''
         , @c_Palletkey       NVARCHAR(60) = ''
         , @c_PGrossWeight    FLOAT = 0.00
         , @c_CBM             FLOAT = 0.00
         , @n_LineNumber      INT = 10
         , @c_DropID          NVARCHAR(50) = ''
    
    CREATE TABLE #PACKLIST62 
            ( Company          NVARCHAR(90) NULL  
            , Addr2            NVARCHAR(90) NULL   
            , Zip_City         NVARCHAR(90) NULL  
            , Country          NVARCHAR(60) NULL  
            , SUSR1            NVARCHAR(40) NULL  
            , Vessel           NVARCHAR(60) NULL  
            , Lott07           NVARCHAR(40) NULL   
            , LoadingPlace     NVARCHAR(60) NULL 
            , DischargePlace   NVARCHAR(60) NULL   
            , MbolKey          NVARCHAR(20) NULL  
            , DepartureDate    DATETIME NULL   
            , FinalDest        NVARCHAR(30) NULL  
            , HSCode           NVARCHAR(90) NULL  
            , Descr            NVARCHAR(200) NULL  
            , SKU              NVARCHAR(200) NULL  
            , Qty              FLOAT NULL
            , Palletkey        NVARCHAR(60) NULL  
            , StdGrossWgt      FLOAT NULL
            , PGrossWeight     FLOAT NULL 
            , CBM              FLOAT NULL
            , Orderkey         NVARCHAR(20) NULL 
            , ShowInvoiceDate  NVARCHAR(1) NULL   --WL02
            )   

    IF( @n_continue = 1 OR @n_continue = 2 )       
    BEGIN
      INSERT INTO #PACKLIST62 (  
                    Company        
                  , Addr2          
                  , Zip_City       
                  , Country        
                  , SUSR1          
                  , Vessel         
                  , Lott07         
                  , LoadingPlace   
                  , DischargePlace 
                  , MbolKey        
                  , DepartureDate  
                  , FinalDest      
                  , HSCode         
                  , DESCR
                  , SKU            
                  , Qty            
                  , Palletkey         
                  , StdGrossWgt    
                  , PGrossWeight   
                  , CBM 
                  , Orderkey 
                  , ShowInvoiceDate  --WL02                  
                )   
                       
      SELECT DISTINCT STO.Company
             ,STO.Address2
             ,LTRIM(RTRIM(ISNULL(STO.Zip,''))) + ' ' + LTRIM(RTRIM(ISNULL(STO.City,'')))
             ,STO.Country
             ,'EORI-NUMBER: ' + LTRIM(RTRIM(STO.SUSR1))
             ,MB.Vessel
             ,L.LOTTABLE07
             ,MB.PlaceOfLoading
             ,MB.PlaceOfDischarge
             ,MB.MbolKey
             ,MB.DepartureDate
             ,ORD.C_City
             ,SC.userdefine02
             ,LTRIM(RTRIM(ISNULL(S.Descr,'')))
             ,LTRIM(RTRIM(ISNULL(S.SKU,'')))
             ,0.00
             ,PDET.RefNo
             ,S.STDGROSSWGT
             ,0.00,0.00
             ,ORD.Orderkey
             ,ISNULL(CL.Short,'N') AS ShowInvoiceDate  --WL02
    FROM MBOL MB WITH (NOLOCK)  
    JOIN MBOLDETAIL MD WITH (NOLOCK) ON MD.MBOLKEY = MB.MBOLKEY --WL01
    JOIN ORDERS ORD WITH (NOLOCK) ON ORD.Orderkey = MD.Orderkey   --WL01 --WL03 --WL04
    JOIN ORDERDETAIL ORDET WITH (NOLOCK) ON ORD.OrderKey = ORDET.OrderKey  
    JOIN PackHeader PH WITH (NOLOCK) ON PH.OrderKey = ORD.OrderKey  
    JOIN PackDetail PDET WITH (NOLOCK) ON PDET.PickSlipNo = PH.PickSlipNo AND PDET.StorerKey = ORDET.StorerKey AND PDET.Sku = ORDET.Sku   --WL04
    JOIN SKUConfig SC WITH (NOLOCK) ON SC.StorerKey = ORDET.StorerKey AND SC.SKU = ORDET.SKU   --WL04
    JOIN SKU S WITH (NOLOCK) ON S.StorerKey = ORDET.StorerKey AND S.SKU = ORDET.SKU  
    JOIN STORER STO WITH (NOLOCK) ON STO.StorerKey = ORD.ConsigneeKey  
    JOIN PICKDETAIL PIDET WITH (NOLOCK) ON ORDET.Orderkey    = PIDET.Orderkey      
                                        AND PIDET.OrderLineNumber = ORDET.OrderLineNumber
                                        AND PIDET.PickDetailKey = PDET.DropID  --WL03
    JOIN LOTATTRIBUTE L WITH (NOLOCK) ON L.SKU = PIDET.SKU AND PIDET.LOT = L.LOT 
    LEFT JOIN CODELKUP CL WITH (NOLOCK) ON CL.Listname = 'REPORTCFG' AND CL.Storerkey = ORD.Consigneekey               --WL02
                                       AND CL.Code2 = 'r_dw_packing_list_62' AND CL.Long = 'r_dw_packing_list_62'      --WL02
                                       AND CL.Code = 'ShowInvoiceDate'                                                 --WL02
    WHERE MB.MbolKey = @c_MBOLKey
    GROUP BY STO.Company
             ,STO.Address2
             ,LTRIM(RTRIM(ISNULL(STO.Zip,''))) + ' ' + LTRIM(RTRIM(ISNULL(STO.City,'')))
             ,STO.Country
             ,'EORI-NUMBER: ' + LTRIM(RTRIM(STO.SUSR1))
             ,MB.Vessel
             ,L.LOTTABLE07
             ,MB.PlaceOfLoading
             ,MB.PlaceOfDischarge
             ,MB.MbolKey
             ,MB.DepartureDate
             ,ORD.C_City
             ,SC.userdefine02
             ,LTRIM(RTRIM(ISNULL(S.Descr,'')))
             ,LTRIM(RTRIM(ISNULL(S.SKU,'')))
             ,PDET.RefNo
             ,S.STDGROSSWGT
             ,ORD.ORDERKEY
             ,ISNULL(CL.Short,'N')  --WL02
    END

    IF( @n_continue = 1 OR @n_continue = 2 )       
    BEGIN
       DECLARE Header_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT DISTINCT Palletkey
       FROM #PACKLIST62
       WHERE MbolKey = @c_MBOLKey

       OPEN Header_CUR   
   
       FETCH NEXT FROM Header_CUR INTO @c_Palletkey
       WHILE @@FETCH_STATUS <> -1
       BEGIN
    
         SELECT @c_PGrossWeight =  @c_PGrossWeight + SUM(GrossWgt)
               ,@c_CBM          =  @c_CBM + SUM(HEIGHT * LENGTH * WIDTH)
         FROM PALLET (NOLOCK)
         WHERE PalletKey = @c_Palletkey

       FETCH NEXT FROM Header_CUR INTO @c_Palletkey            
       END                                                                              
       CLOSE Header_CUR                        
       DEALLOCATE Header_CUR     
       
       UPDATE #PACKLIST62
       SET PGrossWeight = @c_PGrossWeight,
                    CBM = (@c_CBM/1000000)
    END
 
    IF( @n_continue = 1 OR @n_continue = 2 )       
    BEGIN
       DECLARE Qty_CUR CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
       SELECT DISTINCT Orderkey,LTRIM(RTRIM(SKU)), Lott07, Palletkey
       FROM #PACKLIST62
       WHERE MbolKey = @c_MBOLKey

       OPEN Qty_CUR   
   
       FETCH NEXT FROM Qty_CUR INTO @c_orderkey,@c_sku, @c_Lott07, @c_PalletKey
       WHILE @@FETCH_STATUS <> -1
       BEGIN
         --select @c_orderkey,@c_sku, @c_Lott07, @c_PalletKey
         SELECT @n_sumqty = ISNULL(SUM(PIDET.QTY),0)
         FROM PICKDETAIL PIDET(NOLOCK) 
         JOIN LOTATTRIBUTE L (NOLOCK) ON L.SKU = PIDET.SKU AND PIDET.LOT = L.LOT  
         WHERE PIDET.PICKDETAILKEY IN (SELECT DISTINCT PDET.DROPID FROM PACKDETAIL PDET (NOLOCK) WHERE PDET.REFNO = @c_PalletKey)
         AND PIDET.Orderkey = @c_orderkey AND PIDET.SKU = @c_sku AND L.LOTTABLE07 = @c_Lott07

         UPDATE #PACKLIST62
         SET Qty = @n_sumqty
         WHERE Orderkey = @c_orderkey AND Lott07 = @c_Lott07 AND Palletkey = @c_PalletKey AND SKU = @c_sku

       FETCH NEXT FROM Qty_CUR INTO @c_orderkey, @c_sku, @c_Lott07, @c_PalletKey  
       END                                                                            
       CLOSE Qty_CUR                        
       DEALLOCATE Qty_CUR               
    END                            
                    
    SELECT  Company        
          , Addr2          
          , Zip_City       
          , Country        
          , SUSR1          
          , Vessel         
          , Lott07         
          , LoadingPlace   
          , DischargePlace 
          , MbolKey        
          , DepartureDate  
          , FinalDest      
          , HSCode 
          , Descr        
          , SKU            
          , Qty            
          , Palletkey         
          --, CASE WHEN CAST (StdGrossWgt*Qty AS DECIMAL(20,3)) LIKE '%.[1-9]00' THEN FORMAT(StdGrossWgt*Qty,'#.#0') 
          --       WHEN CAST (StdGrossWgt*Qty AS DECIMAL(20,3)) LIKE '%.[1-9][1-9]0' THEN FORMAT(StdGrossWgt*Qty,'#.##') 
          --       ELSE FORMAT(StdGrossWgt*Qty,'#.###')  END AS NetWeight    
          , CAST (StdGrossWgt*Qty AS DECIMAL(20,2)) AS NetWeight
          --, CASE WHEN CAST (PGrossWeight AS DECIMAL(20,3)) LIKE '%.[1-9]00' THEN FORMAT(PGrossWeight,'#.#0') 
          --       WHEN CAST (PGrossWeight AS DECIMAL(20,3)) LIKE '%.[1-9][1-9]0' THEN FORMAT(PGrossWeight,'#.##') 
          --       ELSE FORMAT(PGrossWeight,'#.###')  END AS PGrossWeight 
          , CAST (PGrossWeight AS DECIMAL(20,2)) AS PGrossWeight
          --, CASE WHEN CAST (CBM AS DECIMAL(20,3)) LIKE '%.[1-9]00' THEN FORMAT(CBM,'#.#0') 
          --       WHEN CAST (CBM AS DECIMAL(20,3)) LIKE '%.[1-9][1-9]0' THEN FORMAT(CBM,'#.##') 
          --       ELSE FORMAT(CBM,'#.###')  END AS CBM 
          , CAST (CBM AS DECIMAL(20,2))  AS CBM 
          , Orderkey         
          , @n_LineNumber AS LineNumber
          , (ROW_NUMBER() OVER (PARTITION BY Lott07 ORDER BY Lott07,ORDERKEY,Palletkey ASC)-1)/@n_LineNumber+1 AS PageNo   --WL01
          , ShowInvoiceDate        --WL02
          FROM #PACKLIST62 ORDER BY Lott07,ORDERKEY,Palletkey  --WL01
                 
END  

GO