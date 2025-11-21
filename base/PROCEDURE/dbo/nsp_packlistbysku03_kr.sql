SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/******************************************************************************/    
/* Store Procedure: nsp_PackListBySku03_kr                                    */    
/* Creation Date:                                                             */    
/* Copyright: IDS                                                             */    
/* Written by: GTGOH Duplicate from    nsp_PackListBySku03                    */    
/*                                                                            */    
/* Purpose: Generate PickPack List                                            */    
/*                                                                            */    
/* Called By:                                                                 */    
/*                                                                            */    
/* PVCS Version: 1.3                                                          */    
/*                                                                            */    
/* Version: 5.4                                                               */    
/*                                                                            */    
/* Data Modifications:                                                        */    
/*                                                                            */    
/* Updates:                                                                   */    
/* Date         Author    Ver.  Purposes                                      */  
/* 27-Feb-2017  NJOW01    1.0   WMS-1198 add configure to map size column to  */
/*                              measurement                                   */ 
/* 28-Jan-2019  TLTING_ext 1.1 enlarge externorderkey field length      */  																			
/******************************************************************************/    
    
CREATE PROC [dbo].[nsp_PackListBySku03_kr] (  
   @c_PickSlipNo NVARCHAR(30))    
AS    
   SET NOCOUNT ON  
   SET ANSI_WARNINGS OFF  
   SET QUOTED_IDENTIFIER OFF  
   SET CONCAT_NULL_YIELDS_NULL OFF    
    
BEGIN    
   DECLARE @c_size NVARCHAR(5),    
   @c_qty NVARCHAR(5),    
   @b_success int,    
   @n_err int,    
   @n_continue int,    
   @n_starttcnt int,    
   @c_errmsg NVARCHAR(255),    
   @c_loopcnt int,    
   @theSQLStmt NVARCHAR(255),     
   @c_sku NVARCHAR(50),   
   @c_color NVARCHAR(3),    
   --@c_externorderkey NVARCHAR(30),    
   @c_externorderkey NVARCHAR(50),      --tlting_ext  
   @c_ReprintFlag NVARCHAR(1),   
   @c_BUSR6 NVARCHAR(30) ,  
   @c_Storerkey varchar (30),  
   @c_labelNo varchar (30),   
   @c_orderkey_start NVARCHAR(10),   
   @c_orderkey_end   NVARCHAR(10),  
   @nPosStart int, @nPosEnd int,  
   @nDashPos int    
                    
 SELECT @n_continue=1, @n_starttcnt=@@TRANCOUNT, @theSQLStmt = ''    
   
 IF LEFT(@c_PickSlipNo, 1) <> 'P'   
 BEGIN   
    IF CharIndex('-',@c_PickSlipNo) > 0   
    BEGIN  
      SET @c_PickSlipNo = @c_PickSlipNo  
      SET @nDashPos = charindex('-',@c_PickSlipNo)  
  
      SET @nPosStart = 1  
      SET @nPosEnd = @nDashPos - 1  
      SET @c_orderkey_start=(SELECT substring(@c_PickSlipNo, @nPosStart, @nPosEnd) AS StartOrderKey)  
  
      SET @nPosStart = @nDashPos + 1  
      SET @nPosEnd =  LEN(@c_PickSlipNo) - @nDashPos  
      SET @c_orderkey_end = (SELECT substring(@c_PickSlipNo, @nPosStart, @nPosEnd) AS EndOrderKey)  
    END   
    ELSE  
    BEGIN  
      SET @c_orderkey_start = @c_PickSlipNo  
      SET @c_orderkey_end = @c_PickSlipNo  
    END   
 END   
  
 IF (@c_orderkey_start <> @c_orderkey_end)    
 BEGIN    
    SELECT @c_ReprintFlag = '*'     
 END    
 ELSE     
 BEGIN    
    SELECT @c_ReprintFlag = ' '     
 END    
   
 CREATE Table #TempNPPL (  
   C_Company NVARCHAR(80),  
   c_address1 NVARCHAR(45),  
   c_address2 NVARCHAR(45),  
   c_address3 NVARCHAR(45),  
   c_address4 NVARCHAR(45),  
   c_city NVARCHAR(45),  
   c_state     NVARCHAR(45),                                                                        --(Wan01)  
   c_country NVARCHAR(45),  
   c_contact1  NVARCHAR(30),                                                                        --(Wan01)  
   c_phone1 NVARCHAR(20),  
   OrderKey NVARCHAR(30),  
  -- ExternOrderKey NVARCHAR(20),  
   ExternOrderKey NVARCHAR(50),    --tlting_ext  
   SKU NVARCHAR(20),  
   Color NVARCHAR(3),  
   labelno NVARCHAR(30),  
   storerkey NVARCHAR(10),  
   pickslipno NVARCHAR(10),  
   ReprintFlag NVARCHAR(1),  
   SizeCOL1 NVARCHAR(5)  NULL, QtyCOL1 NVARCHAR(5)  NULL,    
   SizeCOL2 NVARCHAR(5)  NULL, QtyCOL2 NVARCHAR(5)  NULL,    
   SizeCOL3 NVARCHAR(5)  NULL, QtyCOL3 NVARCHAR(5)  NULL,    
   SizeCOL4 NVARCHAR(5)  NULL, QtyCOL4 NVARCHAR(5)  NULL,    
   SizeCOL5 NVARCHAR(5)  NULL, QtyCOL5 NVARCHAR(5)  NULL,    
   SizeCOL6 NVARCHAR(5)  NULL, QtyCOL6 NVARCHAR(5)  NULL,    
   SizeCOL7 NVARCHAR(5)  NULL, QtyCOL7 NVARCHAR(5)  NULL,    
   SizeCOL8 NVARCHAR(5)  NULL, QtyCOL8 NVARCHAR(5)  NULL,    
   SizeCOL9 NVARCHAR(5)  NULL, QtyCOL9 NVARCHAR(5)  NULL,    
   SizeCOL10 NVARCHAR(5) NULL, QtyCOL10 NVARCHAR(5) NULL,    
   SizeCOL11 NVARCHAR(5) NULL, QtyCOL11 NVARCHAR(5) NULL,    
   SizeCOL12 NVARCHAR(5) NULL, QtyCOL12 NVARCHAR(5) NULL,    
   SizeCOL13 NVARCHAR(5) NULL, QtyCOL13 NVARCHAR(5) NULL,    
   SizeCOL14 NVARCHAR(5) NULL, QtyCOL14 NVARCHAR(5) NULL,    
   SizeCOL15 NVARCHAR(5) NULL, QtyCOL15 NVARCHAR(5) NULL,    
   SizeCOL16 NVARCHAR(5) NULL, QtyCOL16 NVARCHAR(5) NULL,    
   SizeCOL17 NVARCHAR(5) NULL, QtyCOL17 NVARCHAR(5) NULL,    
   SizeCOL18 NVARCHAR(5) NULL, QtyCOL18 NVARCHAR(5) NULL,    
   SizeCOL19 NVARCHAR(5) NULL, QtyCOL19 NVARCHAR(5) NULL,    
   SizeCOL20 NVARCHAR(5) NULL, QtyCOL20 NVARCHAR(5) NULL,  
   SizeCOL21 NVARCHAR(5) NULL, QtyCOL21 NVARCHAR(5) NULL,    
   SizeCOL22 NVARCHAR(5) NULL, QtyCOL22 NVARCHAR(5) NULL,    
   SizeCOL23 NVARCHAR(5) NULL, QtyCOL23 NVARCHAR(5) NULL,    
   SizeCOL24 NVARCHAR(5) NULL, QtyCOL24 NVARCHAR(5) NULL,    
   SizeCOL25 NVARCHAR(5) NULL, QtyCOL25 NVARCHAR(5) NULL,    
   SizeCOL26 NVARCHAR(5) NULL, QtyCOL26 NVARCHAR(5) NULL,    
   SizeCOL27 NVARCHAR(5) NULL, QtyCOL27 NVARCHAR(5) NULL,    
   SizeCOL28 NVARCHAR(5) NULL, QtyCOL28 NVARCHAR(5) NULL,    
   SizeCOL29 NVARCHAR(5) NULL, QtyCOL29 NVARCHAR(5) NULL,    
   SizeCOL30 NVARCHAR(5) NULL, QtyCOL30 NVARCHAR(5) NULL,  
   TotalCarton int NULL,  
   Company NVARCHAR(45),  
   Loadkey NVARCHAR(15),   --SOS#121229  
   BuyerPO NVARCHAR(20) NULL)                                                                       --(Wan03)  
   --(Wan01) - START  
   --INSERT INTO #TempNPPL (C_Company,c_address1,c_address2,c_address3,c_address4,c_City,c_country,c_phone1,  
   INSERT INTO #TempNPPL (C_Company,c_address1,c_address2,c_address3,c_address4,c_City,c_State,c_country,c_Contact1,c_phone1,  
   --(Wan01) - END  
                          OrderKey,ExternOrderKey,SKU,Color,labelno,storerkey,pickslipno ,ReprintFlag, Company,Loadkey,  
                          BuyerPO)                                                                 --(Wan03)  
   SELECT ISNULL (max(o.c_company), ' ')   
         + '(' + ISNULL(RTRIM(max(o.BillToKey)), ' ') + '-'                                     --(Wan01)  
         + ISNULL(RTRIM(max(o.ConsigneeKey)), ' ') + ')' c_company,                             --(Wan01)   
          ISNULL (max(o.c_address1), ' ' )c_address1,     
          ISNULL (max(o.c_address2), ' ') c_address2,     
          ISNULL (max(o.c_address3), ' ') c_address3,     
          ISNULL (max(o.c_address4), ' ' ) c_address4,     
          ISNULL (max(o.c_city), ' ' ) c_City,   
          ISNULL (max(o.c_State), ' ' ) c_State,                                                   --(Wan01)   
          ISNULL (max(o.c_country), ' ' ) c_country,  
          ISNULL (max(o.c_Contact1), ' ' ) c_Contact1,                                             --(Wan01)    
          ISNULL (max(o.c_phone1), ' ' )c_phone1,    
          max(o.orderkey)OrderKey,  
          max(o.externorderkey) ExternOrderKey,       
          max(s.style)SKU,  
          max(s.color) Color,  
          max(pd.cartonNo)labelno,  
          max(o.storerkey)storerkey,  
          max(pd.pickslipno)pickslipno,  
          @c_ReprintFlag ReprintFlag,            
          ISNULL (max(ST.company), ' ')  Company,  
          ISNULL (max(o.Loadkey), ' ')  Loadkey,  
          ISNULL (MAX(o.BuyerPO), ' ') BuyerPO                                                     --(Wan03)                                    
   FROM ORDERS o WITH (NOLOCK)  
        JOIN ORDERDETAIL OD WITH (NOLOCK)  
      ON (O.OrderKey = OD.OrderKey)  
        JOIN Packheader PH WITH (NOLOCK)   
      ON (o.Orderkey = PH.Orderkey and o.storerkey = PH.storerkey)                                       --(Wan02)  
        JOIN packdetail pd WITH (NOLOCK)   
      ON (PH.pickslipno = pd.pickslipno and PH.storerkey = pd.storerkey and od.sku = pd.sku)   
        JOIN sku s WITH  (NOLOCK)   
      ON (OD.storerkey = s.storerkey AND OD.sku = s.sku)  
         JOIN STORER ST WITH (NOLOCK)  
      ON (O.StorerKey = ST.StorerKey)  
   WHERE PH.pickslipno = @c_PickSlipNo OR (o.orderkey  >= @c_orderkey_start AND o.orderkey <=  @c_orderkey_end)  
   GROUP BY pd.labelno,o.LoadKey,s.style,s.color  
--   ORDER BY o.orderkey ASC--,substring(OD.sku,1,9)    
  
   
   DECLARE nppl_cur CURSOR FAST_FORWARD READ_ONLY FOR    
   SELECT sku, storerkey , Pickslipno, LabelNo,color  
   FROM #TempNPPL  
   OPEN nppl_cur    
    
   FETCH NEXT FROM nppl_cur INTO @c_sku, @c_Storerkey,@c_Pickslipno, @c_labelNo,@c_color  
   
   WHILE @@FETCH_STATUS = 0    
     
   BEGIN          
         DECLARE size_cur CURSOR FAST_FORWARD READ_ONLY FOR   
  
         -- SELECT SUBSTRING(s.size,1,3) SIZE, -- SOS# 143326  
         SELECT
            CASE WHEN ISNULL(C.Code,'') <> '' THEN 
                 CASE WHEN s.measurement IN ('','U') THEN SUBSTRING(s.size,1,4) ELSE ISNULL(s.measurement,'') END
            ELSE SUBSTRING(s.size,1,4) END [Size],  --NJOW01 
            --SUBSTRING(s.size,1,4) SIZE,  
            pd.Qty ,    
            s.BUSR6 BUSR6 , pd.cartonNo  
         FROM packdetail pd WITH (NOLOCK)  
         JOIN sku s WITH (NOLOCK) ON (pd.sku = s.sku AND pd.storerkey = s.storerkey)  
         LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.Storerkey= PD.Storerkey
                                            AND C.listname = 'REPORTCFG' and C.Code ='GetSkuMeasurement'
	                                          AND long='r_dw_packing_list_by_sku03_kr' AND ISNULL(C.Short,'') <> 'N' --NJOW01
         WHERE s.storerkey = @c_Storerkey   
         AND pd.PickSlipNo = @c_PickSlipNo  
         -- SOS# 110426 (HFLiew01)  
         -- AND SUBSTRING(pd.sku,1,10) = dbo.fnc_RTrim(dbo.fnc_LTrim(substring(@c_sku, 1,10)))  
         AND s.Style = @c_sku  
         AND s.color = @c_color  
         AND pd.cartonNo =  @c_labelNo  
--          GROUP BY substring(s.size,1,3),  pd.Qty ,  s.BUSR6  , pd.labelno  
         --(Wan01) - START  
         --ORDER BY s.BUSR6   
         ORDER BY 
            CASE WHEN ISNULL(C.Code,'') <> '' THEN 
                 CASE WHEN s.measurement IN ('','U') THEN SUBSTRING(s.size,1,4) ELSE ISNULL(s.measurement,'') END
            ELSE SUBSTRING(s.size,1,4) END   --NJOW01                
          --SUBSTRING(s.size,1,4)  
         --(Wan01) - END   
         
         OPEN size_cur   
      
         SELECT @c_loopcnt = 1     
         FETCH NEXT FROM size_cur INTO @c_size, @c_qty, @C_BUSR6 ,  @c_labelNo  
         WHILE @@FETCH_STATUS = 0     
         BEGIN    
            SELECT @theSQLStmt = 'UPDATE #TempNPPL SET SizeCOL'+dbo.fnc_RTrim(cast(@c_loopcnt AS CHAR))+'=N'''+dbo.fnc_RTrim(ISNULL(@c_size,''))    
            SELECT @theSQLStmt = @theSQLStmt+''', QtyCOL'+dbo.fnc_RTrim(cast(@c_loopcnt AS CHAR))+'=N'''+dbo.fnc_RTrim(ISNULL(@c_qty, '0'))+''''    
            SELECT @theSQLStmt = @theSQLStmt+' WHERE dbo.fnc_LTrim(SUBSTRING(sku,1,10)) = N'''+dbo.fnc_RTrim(dbo.fnc_LTrim(SUBSTRING(@c_sku,1,10)))  
                                 +''' AND pickslipno = N'''+dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Pickslipno))+''' AND color = N'''+dbo.fnc_RTrim(dbo.fnc_LTrim(@c_Color))  
                         +''' AND labelNo = N'''+dbo.fnc_RTrim(dbo.fnc_LTrim(@c_labelno))+''''    
            EXEC(@theSQLStmt)    
            SELECT @c_loopcnt = @c_loopcnt + 1    
            FETCH NEXT FROM size_cur INTO @c_size, @c_qty, @C_BUSR6  ,@c_labelNo                                                                                     
         END -- size_cur WHILE loop     
   
         CLOSE size_cur    
         DEALLOCATE size_cur    
       
      FETCH NEXT FROM nppl_cur INTO @c_sku, @c_Storerkey,@c_Pickslipno ,@c_labelNo,@c_color  
   
   END -- nppl_cur WHILE loop    
    
   CLOSE nppl_cur    
   DEALLOCATE nppl_cur    
  
   SELECT @c_loopcnt = 1     
   WHILE @c_loopcnt <= 30  
   BEGIN  
      SELECT @theSQLStmt = 'UPDATE #TempNPPL SET QtyCOL'+dbo.fnc_RTrim(cast(@c_loopcnt AS CHAR))+'= ISNULL(QtyCOL'+dbo.fnc_RTrim(cast(@c_loopcnt AS NVARCHAR(2))) + ',0), ' +   
                           'SizeCOL'+dbo.fnc_RTrim(cast(@c_loopcnt AS CHAR))+'= ISNULL(SizeCOL'+dbo.fnc_RTrim(cast(@c_loopcnt AS NVARCHAR(2))) + ','''') '   
      EXEC(@theSQLStmt)   
  
      SELECT @c_loopcnt = @c_loopcnt + 1          
   END  
    
   UPDATE #TempNPPL  
      SET TotalCarton = OrdTotCarton.TotCarton  
   FROM #TempNPPL TP  
   JOIN (SELECT PH.LoadKey, Max(PD.CartonNo) AS TotCarton FROM #TempNPPL O   
                                              JOIN Packheader PH WITH (NOLOCK) ON (o.LoadKey = PH.LoadKey)  
                                              JOIN PackDetail PD WITH (NOLOCK) ON (PH.pickslipno = pd.pickslipno)  
                                              WHERE PH.PickSlipNo = @c_PickSlipNo                  --(Wan02)     
         GROUP BY PH.LoadKey) AS OrdTotCarton ON TP.LoadKey = OrdTotCarton.LoadKey   
  
   SELECT *    
   FROM #TempNPPL  
   ORDER BY  Pickslipno, storerkey,   
             CAST(labelno as INT), -- 03-Jul-2008 Shong  
             sku,  
             color   
  
                        
   DROP TABLE #TempNPPL  
    
END    

GO