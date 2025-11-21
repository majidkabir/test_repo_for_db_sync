SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
  
/***************************************************************************/  
/* Stored Procedure: ispMBFZ03                                             */  
/* Creation Date: 25-JAN-2020                                              */  
/* Copyright: LFL                                                          */  
/* Written by:                                                             */  
/*                                                                         */  
/* Purpose: WMS-16002 - RG - LEGO - EXCEED MBol Finalization               */  
/*                      Computer transport rate                            */  
/*                      Set Finalization Date (WMS-15974)                  */  
/*                                                                         */  
/* Called By: ispFinalizeMBOL (Storerconfig: PostFinalizeMBOL_SP)          */  
/*                                                                         */  
/* GitLab Version: 1.0                                                     */  
/*                                                                         */  
/* Version: 5.4                                                            */  
/*                                                                         */  
/* Data Modifications:                                                     */  
/*                                                                         */  
/* Updates:                                                                */  
/* Date         Author  Ver   Purposes                                     */  
/* 10-Mar-2021  NJOW01  1.0   Include zone max rate calculation            */    
/* 24-Mar-2021  NJOW02  1.1   WMS-16644 include export order calculation   */  
/* 15-Apr-2021  NJOW03  1.2   WMS-16834 Change VAT formula                 */  
/* 02-Sep-2021  NJOW04  1.3   WMS-17846 Add Macau handling for HK MO       */  
/* 28-Sep-2021  NJOW    1.4   DEVOPS script combine                        */                    
/* 30-Sep-2021  NJOW05  1.5   WMS-18059 add distributed pallet weight      */                    
/* 28-Mar-2023  NL01    1.6   WMS-22148 change total volume rounded logic  */  
/***************************************************************************/    
CREATE   PROC [dbo].[ispMBFZ03]    
(     @c_MBOLKey     NVARCHAR(10)     
  ,   @b_Success     INT           OUTPUT  
  ,   @n_Err         INT           OUTPUT  
  ,   @c_ErrMsg      NVARCHAR(255) OUTPUT     
)    
AS    
BEGIN    
   SET NOCOUNT ON    
   SET QUOTED_IDENTIFIER OFF    
   SET ANSI_NULLS OFF    
   SET CONCAT_NULL_YIELDS_NULL OFF    
        
   DECLARE @n_Continue INT,  
           @n_StartTranCount INT,  
           @c_Storerkey NVARCHAR(15),  
           @c_Facility NVARCHAR(5),  
           @n_DelNo INT,  
           @c_OrderList NVARCHAR(250),  
           @c_Consigneekey NVARCHAR(15),   
           @c_Zone NVARCHAR(50),  
           @n_ZoneMaxRate DECIMAL(15,2),  
           @c_Containerkey NVARCHAR(20),   
           @c_Orderkey NVARCHAR(10),  
           @n_NoofPallet_ord DECIMAL(15,3),   
           @n_NoofContainer_ord INT,  
           @n_TotPallet DECIMAL(15,3),   
           @n_Totpalletvol DECIMAL(15,6),  
           @n_TotPalletGrossWgt DECIMAL(15,6),  
           @n_SurchargeRate DECIMAL(15,4),   
           @n_VATRate DECIMAL(15,4),   
           @n_PalletVolume DECIMAL(15,6),  
           @n_PalletGrossWgt DECIMAL(15,6),  
           @n_TotFullCarton INT,    
           @n_TotFullCartonVol DECIMAL(15,6),  
           @n_TotLooseCarton INT,   
           @n_TotLooseCartonVol DECIMAL(15,6),  
           @n_TotContainerVol DECIMAL(15,6),   
           @n_TotContainerVolRounded DECIMAL(15,2),   
           @n_TotContainerCarton INT,  
           @n_FreightRate DECIMAL(15,4),   
           @c_FreightType NVARCHAR(10),   
           @n_FreightAmt DECIMAL(15,2),  
           @n_OrderFreightAmt DECIMAL(15,2),  
           @c_ShipmentNo NVARCHAR(10),   
           @n_ShipmentNo BIGINT,  
           @c_NewDeliveryNo NVARCHAR(10),  
           @c_RateString NVARCHAR(500),  
           @c_LabelNo NVARCHAR(20),   
           @n_CartonVol DECIMAL(15,6),   
           @n_CartonGrossWgt DECIMAL(15,6),   
           @n_CartonNetWgt DECIMAL(15,6),   
           @n_TotFullCartonGrossWgt DECIMAL(15,6),   
           @n_TotFullCartonNetWgt DECIMAL(15,6),  
           @n_TotLooseCartonGrossWgt DECIMAL(15,6),  
           @n_TotLooseCartonNetWgt DECIMAL(15,6),   
           @n_TotOrderVol DECIMAL(15,6),  
           @n_TotOrderGrossWgt DECIMAL(15,6),   
           @n_TotOrderNetWgt DECIMAL(15,6),  
           @n_TotOrderCarton INT,  
           @n_FreightSurcharge DECIMAL(15,2),   
           @n_Vat DECIMAL(15,2),  
           @n_TotConsigneeCarton DECIMAL(15,6),  
           @n_TotConsigneeVol DECIMAL(15,6),  
           @n_TotConsigneeVolRounded DECIMAL(15,2),     
           @c_CallSource NVARCHAR(30),  
           @c_Sku NVARCHAR(10),  
           @c_OrderLineNumber NVARCHAR(5),  
           @c_LottableValue NVARCHAR(60),  
           @n_Qty INT,  
           @n_PackQty INT,  
           @n_QtyTake INT,  
           @n_TotCarton INT,  
           @n_DistributePltVol DECIMAL(15,6),  
           @n_DistributePltWgt DECIMAL(15,6),  --NJOW05  
           @n_CaseCnt INT,  
           @n_ExportOrdCnt INT,  
           @n_HK_MOExportOrdCnt INT  
                                                                       
   SELECT @b_Success = 1, @n_Err = 0, @c_ErrMsg = '', @n_Continue = 1, @n_StartTranCount = @@TRANCOUNT  
     
   IF @@TRANCOUNT = 0  
      BEGIN TRAN  
  
   SELECT TOP 1 @c_Storerkey = O.Storerkey,  
                @c_Facility = O.Facility  
   FROM MBOLDETAIL MD (NOLOCK)  
   JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
   WHERE MD.Mbolkey = @c_Mbolkey                
        
   --NJOW01  
   --Validation  
   IF @n_continue IN(1,2)  
   BEGIN  
      --1  
      IF EXISTS (SELECT 1   
                 FROM EXTERNORDERS (NOLOCK)  
                 WHERE ExternOrderkey = @c_Mbolkey  
                 AND Storerkey = @c_Storerkey)  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63310  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': This MBOL was processed! (ispMBFZ03)' + ' ( '  
                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         GOTO QUIT_SP                                  
      END   
                   
      SET @c_OrderList = ''  
      SELECT @c_OrderList = @c_OrderList + RTRIM(MD.Orderkey) + ','  
      FROM MBOLDETAIL MD (NOLOCK)  
      JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
      JOIN STORER S (NOLOCK) ON O.Consigneekey = S.Storerkey  
      WHERE MD.Mbolkey = @c_Mbolkey  
      AND S.PalletMgmtFlag = 'Y'  
      AND (ISNULL(O.C_Vat,'') = ''  
          OR ISNUMERIC(O.C_Vat) <> 1  
          OR O.C_Vat <= '0')  
      ORDER BY O.Orderkey      
        
      IF @c_OrderList <> ''  
      BEGIN  
        SET @c_OrderList = LEFT(@c_OrderList, LEN(@c_OrderList) - 1)  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63320  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No of pallet is not provided. Order: ' + @c_OrderList + ' (ispMBFZ03)'   
         GOTO QUIT_SP                  
      END  
              
      SET @c_OrderList = ''  
      SELECT @c_OrderList = @c_OrderList + RTRIM(O.Orderkey) + ','  
      FROM MBOLDETAIL MD (NOLOCK)  
      JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
      JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
      LEFT JOIN PALLETDETAIL PLD(NOLOCK) ON PD.LabelNo = PLD.CaseID  
      LEFT JOIN CONTAINERDETAIL CD (NOLOCK) ON PLD.Palletkey = CD.PalletKey   
      WHERE MD.Mbolkey = @c_Mbolkey  
      AND (PLD.Palletkey IS NULL OR CD.Palletkey IS NULL)  
      AND O.Consigneekey IN(SELECT DISTINCT O.Consigneekey        
                            FROM MBOLDETAIL MD (NOLOCK)  
                            JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                            JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                            JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                            JOIN PALLETDETAIL PLD(NOLOCK) ON PD.LabelNo = PLD.CaseID  
                            JOIN CONTAINERDETAIL CD (NOLOCK) ON PLD.Palletkey = CD.PalletKey   
                            WHERE MD.Mbolkey = @c_Mbolkey)  
      GROUP BY O.Orderkey                        
        
      IF @c_OrderList <> ''  
      BEGIN  
        SET @c_OrderList = LEFT(@c_OrderList, LEN(@c_OrderList) - 1)  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63330  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Order/Carton not scan to container: ' + @c_OrderList + ' (ispMBFZ03)'   
         GOTO QUIT_SP                  
      END  
              
      /*  
      SET @c_OrderList = ''  
      SELECT @c_OrderList = @c_OrderList + RTRIM(O.Orderkey) + ','  
      FROM MBOLDETAIL MD (NOLOCK)  
      JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
      JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
      LEFT JOIN PALLETDETAIL PLD(NOLOCK) ON PD.LabelNo = PLD.CaseID  
      WHERE MD.Mbolkey = @c_Mbolkey  
      GROUP BY O.Orderkey  
      HAVING SUM(PD.Qty) <> SUM(ISNULL(PLD.Qty,0)) AND SUM(ISNULL(PLD.Qty,0)) > 0  
  
      IF @c_OrderList <> ''  
      BEGIN  
        SET @c_OrderList = LEFT(@c_OrderList, LEN(@c_OrderList) - 1)  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63340  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Order scan to container not tally with pack qty: ' + @c_OrderList + ' (ispMBFZ03)'   
         GOTO QUIT_SP                  
      END  
      */      
       
      SET @n_DelNo = 0  
      SELECT @n_DelNo = CASE WHEN ISNUMERIC(Short) = 1 THEN CAST(Short AS BIGINT) ELSE 0 END  
      FROM CODELKUP (NOLOCK)   
      WHERE Listname = 'CUSTPARAM'  
      AND Code = 'NEWDELVALERT'  
        
      IF EXISTS(SELECT 1   
                FROM NCOUNTER (NOLOCK)  
                WHERE keyname = 'LEGO_NEWNO'  
                AND AlphaCount - KeyCount < @n_Delno)  
         AND @n_DelNo > 0                
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63350  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': No of new delivery no less than ' + RTRIM(CAST(@n_DelNo AS NVARCHAR)) + '. Request new range. (ispMBFZ03)'   
         GOTO QUIT_SP                  
      END                               
   END  
  
   IF @n_continue IN (1,2)  
   BEGIN      
      UPDATE MBOL WITH (ROWLOCK)  
      SET MBOL.Userdefine07 = GETDATE()  
      WHERE MBOL.MBOLKey = @c_MBOLKey  
  
      SELECT @n_err = @@ERROR  
        
      IF @n_err <> 0  
      BEGIN  
         SELECT @n_continue = 3  
         SELECT @c_errmsg = CONVERT(char(250),@n_err), @n_err = 63300  
         SELECT @c_errmsg='NSQL'+CONVERT(char(5),@n_err)+': Update MBOL Table Failed! (ispMBFZ03)' + ' ( '  
                         + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) '  
         GOTO QUIT_SP                                  
      END  
   END  
     
   --Retrieve rate --NJOW01  
   IF @n_continue IN(1,2)  
   BEGIN  
      CREATE TABLE #TMP_PICK (Sku NVARCHAR(20), OrderLineNumber NVARCHAR(5), Qty INT)  
        
      --2  
      SET @n_SurchargeRate = 0.00               
      SELECT TOP 1 @n_SurchargeRate = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS DECIMAL(15,4)) ELSE 0 END  
      FROM CODELKUP CL (NOLOCK)  
      WHERE CL.ListName = 'CUSTPARAM'  
      AND CL.Storerkey = @c_Storerkey  
      AND CL.Code = 'FMS_EDI'  
      AND CL.Code2 = 'FUEL_SUR'  
        
      --3  
      SET @n_VATRate = 0.00  
      SELECT TOP 1 @n_VATRate = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS DECIMAL(15,4)) ELSE 0 END  
      FROM CODELKUP CL (NOLOCK)  
      WHERE CL.ListName = 'CUSTPARAM'  
      AND CL.Storerkey = @c_Storerkey  
      AND CL.Code = 'FMS_EDI'  
      AND CL.Code2 = 'VAT'      
  
      SET @n_PalletVolume = 0.00  
      SELECT TOP 1 @n_PalletVolume = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS DECIMAL(15,6)) ELSE 0 END  
      FROM CODELKUP CL (NOLOCK)  
      WHERE CL.ListName = 'CUSTPARAM'  
      AND CL.Storerkey = @c_Storerkey  
      AND CL.Code = 'FMS_PALLETVOLUME'  
        
      SET @n_PalletGrossWgt = 0.00  
      SELECT TOP 1 @n_PalletGrossWgt = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS DECIMAL(15,6)) ELSE 0 END  
      FROM CODELKUP CL (NOLOCK)  
      WHERE CL.ListName = 'CUSTPARAM'  
      AND CL.Storerkey = @c_Storerkey  
      AND CL.Code = 'FMS_PalletGRWGT'  
   END     
        
   --4,5,6 Process for consignee with scan to container --NJOW01  
   IF @n_continue IN(1,2)  
   BEGIN                   
      --loop consignee  
      DECLARE CURSOR_CONSIGNEE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT O.Consigneekey, ISNULL(Z.Long,'') AS Zone,  
                CASE WHEN ISNUMERIC(Z.Short) = 1 THEN CAST(Z.Short AS DECIMAL(15,2)) ELSE 0 END,  --NJOW01  
                SUM(CASE WHEN ISNULL(O.C_Country,'') <> ISNULL(S.Country,'') THEN 1 ELSE 0 END), --NJOW02  
                SUM(CASE WHEN ISNULL(O.C_Country,'') ='MO' AND ISNULL(S.Country,'') = 'HK' THEN 1 ELSE 0 END) --NJOW03                  
         FROM MBOLDETAIL MD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
         JOIN STORER S (NOLOCK) ON O.Storerkey = S.Storerkey  --NJOW02  
         OUTER APPLY (SELECT TOP 1 CL.Long, CL.Short FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = 'CUSTPARAM' AND CL.Code = 'FMS_ZONE'   
                      AND CAST(CL.UDF01 AS BIGINT) <= CAST(CASE WHEN ISNUMERIC(O.C_Zip) = 1 THEN O.C_Zip ELSE 1 END AS BIGINT)   
                      AND CAST(CL.UDF02 AS BIGINT) >= CAST(CASE WHEN ISNUMERIC(O.C_Zip) = 1 THEN O.C_Zip ELSE 1 END AS BIGINT)) AS Z  
         JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
         JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
         JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
         JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey  
         WHERE MD.Mbolkey = @c_Mbolkey  
         GROUP BY O.Consigneekey, ISNULL(Z.Long,''),  
                  CASE WHEN ISNUMERIC(Z.Short) = 1 THEN CAST(Z.Short AS DECIMAL(15,2)) ELSE 0 END  --NJOW01     
         ORDER BY O.Consigneekey                
        
      OPEN CURSOR_CONSIGNEE  
        
      FETCH NEXT FROM CURSOR_CONSIGNEE INTO @c_Consigneekey, @c_Zone, @n_ZoneMaxRate, @n_ExportOrdCnt, @n_HK_MOExportOrdCnt         
        
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
      BEGIN  
        IF @n_HK_MOExportOrdCnt > 0  --NJOW03  
        BEGIN  
           SET @c_Zone = 'MOEXPORT'  
        END  
        ELSE IF @n_ExportOrdCnt > 0   --NJOW02  
        BEGIN  
           SET @c_Zone = 'NA'  
           SET @n_ZoneMaxRate = 1  
        END  
                                         
        --loop consignee->container  
         DECLARE CURSOR_CONSCONTAINER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
            SELECT CTD.Containerkey  
            FROM MBOLDETAIL MD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
            JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
            JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
            JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
            JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey  
            WHERE MD.Mbolkey = @c_Mbolkey  
            AND O.Consigneekey = @c_Consigneekey  
            GROUP BY CTD.Containerkey  
            ORDER BY CTD.Containerkey                
           
         OPEN CURSOR_CONSCONTAINER  
           
         FETCH NEXT FROM CURSOR_CONSCONTAINER INTO @c_Containerkey        
           
         WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
         BEGIN  
            SET @n_Totpallet = 0.00  
            SET @n_Totpalletvol = 0.00  
            SET @n_TotPalletGrossWgt = 0.00  
            SET @n_TotFullCarton = 0   
            SET @n_TotFullCartonVol = 0.00   
            SET @n_TotLooseCarton = 0   
            SET @n_TotLooseCartonVol = 0.00  
            SET @n_TotContainerCarton = 0  
            SET @n_TotContainerVol = 0.00  
              
            --------------create freight by container----------------    
            IF @n_continue IN(1,2)  
            BEGIN                 
               --calculate total pallet & volume              
               --loop consignee->container->order  
               DECLARE CURSOR_CONORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT O.Orderkey,    
                         CASE WHEN ISNUMERIC(O.c_Vat) = 1 THEN CAST(O.c_Vat AS DECIMAL(15,3)) ELSE 0 END AS noofpallet_ord,  
                         ISNULL(OC.noofcontainer_ord,0)  
                  FROM MBOLDETAIL MD (NOLOCK)  
                  JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                  OUTER APPLY (SELECT COUNT(DISTINCT CTD2.Containerkey) AS noofcontainer_ord  
                               FROM PACKHEADER PH2 (NOLOCK)   
                               JOIN PACKDETAIL PD2 (NOLOCK) ON PH2.Pickslipno = PD2.Pickslipno  
                               JOIN PALLETDETAIL PLD2 (NOLOCK) ON PD2.LabelNo = PLD2.CaseID  
                               JOIN CONTAINERDETAIL CTD2 (NOLOCK) ON PLD2.Palletkey = CTD2.Palletkey  
                               WHERE PH2.Orderkey = O.Orderkey) AS OC  
                  JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                  JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                  JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
                  JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey  
                  WHERE MD.Mbolkey = @c_Mbolkey  
                  AND CTD.Containerkey = @c_Containerkey  
                  AND O.Consigneekey = @c_Consigneekey                 
                  GROUP BY O.Orderkey,   
                           CASE WHEN ISNUMERIC(O.c_Vat) = 1 THEN CAST(O.c_Vat AS DECIMAL(15,3)) ELSE 0 END,  
                           ISNULL(OC.noofcontainer_ord,0)   
                  ORDER BY O.Orderkey                
                 
               OPEN CURSOR_CONORDER                                                     
                                                                                             
               FETCH NEXT FROM CURSOR_CONORDER INTO @c_Orderkey, @n_noofpallet_ord, @n_noofcontainer_ord  
                                                                                        
               WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
               BEGIN  
                 SET @n_totpallet = @n_totpallet + ROUND((@n_noofpallet_ord / (@n_noofcontainer_ord * 1.0)), 3)    
                   
                  FETCH NEXT FROM CURSOR_CONORDER INTO @c_Orderkey, @n_noofpallet_ord, @n_noofcontainer_ord  
               END           
               CLOSE CURSOR_CONORDER  
               DEALLOCATE CURSOR_CONORDER    
                 
               --calculate total pallet volumn  
               SET @n_totpalletvol = ROUND(@n_totpallet * @n_PalletVolume, 6)  
                 
               --calculate total pallet gross weight  
               SET @n_TotPalletGrossWgt = ROUND(@n_totpallet * @n_PalletGrossWgt, 6)  
                 
               --calculate total full carton & volume              
               SELECT @n_TotFullCarton = COUNT(DISTINCT FC.LabelNo),  
                      @n_TotFullCartonVol = ISNULL(SUM(FC.CtnVolume),0)  
               FROM (SELECT PD.LabelNo, ROUND(MAX(Sku.Cube),6) AS CtnVolume  
                     FROM MBOLDETAIL MD (NOLOCK)  
                     JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                     JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                     JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                     JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
                     JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
                     JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey  
                     WHERE MD.Mbolkey = @c_Mbolkey  
                     AND CTD.Containerkey = @c_Containerkey  
                     AND O.Consigneekey = @c_Consigneekey              
                     GROUP BY PD.LabelNo  
                     HAVING COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) = MAX(PACK.Casecnt)  
                   ) AS FC  
                               
               --calculate total loose carton & volume              
               SELECT @n_TotLooseCarton = COUNT(DISTINCT LC.LabelNo),  
                      @n_TotLooseCartonVol = ISNULL(SUM(LC.LooseCtnVolume),0)  
               FROM (SELECT PD.LabelNo, ROUND(SUM(SKU.StdCube * PD.Qty),6) AS LooseCtnVolume  
                     FROM MBOLDETAIL MD (NOLOCK)  
                     JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                     JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                     JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                     JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
                     JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
                     JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey  
                     WHERE MD.Mbolkey = @c_Mbolkey  
                     AND CTD.Containerkey = @c_Containerkey  
                     AND O.Consigneekey = @c_Consigneekey              
                     GROUP BY PD.LabelNo  
                     HAVING COUNT(DISTINCT PD.Sku) > 1 OR (COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) <> MAX(PACK.Casecnt))  
                   ) AS LC  
                 
               --calculate total container volume  
               SET @n_TotContainerVol = ISNULL(@n_TotPalletVol,0) + ISNULL(@n_TotFullCartonVol,0) + ISNULL(@n_TotLooseCartonVol,0)  
               --SET @n_TotContainerVolRounded = CASE WHEN (@n_TotContainerVol - ROUND(@n_TotContainerVol,2,1)) > 0 THEN ROUND(@n_TotContainerVol,2,1) + 0.01 ELSE ROUND(@n_TotContainerVol,2,1) END --NJOW02  
                 
				       --NL01 S
				       SET @n_TotContainerVolRounded = CASE WHEN ROUND(@n_TotContainerVol,2) >  @n_TotContainerVol THEN ROUND(@n_TotContainerVol,2)
				       									 WHEN ROUND(@n_TotContainerVol,2) <= @n_TotContainerVol AND (ROUND(@n_TotContainerVol,3) - ROUND(@n_TotContainerVol,2)) > 0 THEN ROUND(@n_TotContainerVol,2,1) + 0.01 
				       									 ELSE ROUND(@n_TotContainerVol,2,1) END
				       --NL01 E

               --calculate total container carton  
               SET @n_TotContainerCarton = @n_TotFullCarton + @n_TotLooseCarton  
                 
               --calculate freight amount  
               SET @n_FreightRate = 0.00  
               SET @c_FreightType = ''                    
               SET @n_FreightAmt = 0.00  
               SELECT TOP 1 @n_FreightRate = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS DECIMAL(15,4)) ELSE 0 END,  
                            @c_FreightType = CL.Short  
               FROM CODELKUP CL (NOLOCK)  
               WHERE CL.ListName = 'CUSTPARAM'  
               AND CL.Storerkey = @c_Storerkey  
               AND CL.Code = 'FMS_FRTCHARGE'  
               AND CAST(CL.UDF01 AS DECIMAL(15,4)) < @n_TotContainerVolRounded  
               AND CAST(CL.UDF02 AS DECIMAL(15,4)) >= @n_TotContainerVolRounded  
               AND CL.UDF03 = @c_Zone   
                 
               --NJOW02  
               IF @n_ExportOrdCnt > 0   
                  AND @n_HK_MOExportOrdCnt = 0  --NJOW03  
               BEGIN  
                  SET @n_FreightRate = 1  
                  SET @c_FreightType = 'FIXED'  
               END  
                 
               IF @c_FreightType = 'FIXED'  
                  SET @n_FreightAmt = @n_FreightRate  
               ELSE   
                  SET @n_FreightAmt = ROUND(@n_TotContainerVolRounded * @n_FreightRate,2) --NJOW01                    
                    
               IF @n_FreightAmt > @n_ZoneMaxRate  --NJOW01  
                  AND @n_HK_MOExportOrdCnt = 0 --NJOW03  
                  SET @n_FreightAmt = @n_ZoneMaxRate  
                                      
               SET @c_RateString = FORMAT(@n_FreightRate,'0.######') + '|' + RTRIM(@c_FreightType) + '|' + FORMAT(@n_SurchargeRate,'0.######') + '|' + FORMAT(@n_VATRate,'0.######')    
                              
               /*  
               EXEC dbo.nspg_GetKey                  
                    @KeyName = 'LEGO_SHIPNO'      
                   ,@fieldlength = 10      
                   ,@keystring = @c_ShipmentNo OUTPUT      
                   ,@b_Success = @b_success OUTPUT      
                   ,@n_err = @n_err OUTPUT      
                   ,@c_errmsg = @c_errmsg OUTPUT  
                   ,@b_resultset = 0      
                   ,@n_batch     = 1  
               */                      
                     
               INSERT INTO EXTERNORDERS (ExternOrderkey, Orderkey, Storerkey, Source, PlatformName, PlatformOrderNo, Userdefine01,   
                                         Userdefine02, Userdefine03, Userdefine04, Userdefine05, Userdefine06, userdefine07)  
                                 VALUES (@c_Mbolkey, 'C888888888', @c_Storerkey, @c_Containerkey, @c_RateString, @c_Consigneekey, FORMAT(@n_TotContainerVol,'0.######'),  
                                         CAST(@n_TotFullCarton AS NVARCHAR), CAST(@n_TotLooseCarton AS NVARCHAR), FORMAT(@n_TotFullCartonVol,'0.######'),   
                                         FORMAT(@n_TotLooseCartonVol,'0.######'), FORMAT(@n_FreightAmt,'0.00'), FORMAT(@n_TotPallet,'0.######'))                            
                 
               SET @n_ShipmentNo = @@IDENTITY           
            END             
              
            --------------Create freight by order----------------       
            IF @n_continue IN(1,2)  
            BEGIN  
               --loop consignee->container->order  
               DECLARE CURSOR_CONORDER2 CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT O.Orderkey,    
                         CASE WHEN ISNUMERIC(O.c_Vat) = 1 THEN CAST(O.c_Vat AS DECIMAL(15,3)) ELSE 0 END AS noofpallet_ord,  
                         ISNULL(OC.noofcontainer_ord,0)  
                  FROM MBOLDETAIL MD (NOLOCK)  
                  JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                  OUTER APPLY (SELECT COUNT(DISTINCT CTD2.Containerkey) AS noofcontainer_ord  
                               FROM PACKHEADER PH2 (NOLOCK)   
                               JOIN PACKDETAIL PD2 (NOLOCK) ON PH2.Pickslipno = PD2.Pickslipno  
                               JOIN PALLETDETAIL PLD2 (NOLOCK) ON PD2.LabelNo = PLD2.CaseID  
                               JOIN CONTAINERDETAIL CTD2 (NOLOCK) ON PLD2.Palletkey = CTD2.Palletkey  
                               WHERE PH2.Orderkey = O.Orderkey) AS OC  
                  JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                  JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                  JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
                  JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey  
                  WHERE MD.Mbolkey = @c_Mbolkey  
                  AND CTD.Containerkey = @c_Containerkey  
                  AND O.Consigneekey = @c_Consigneekey                 
                  GROUP BY O.Orderkey,   
                           CASE WHEN ISNUMERIC(O.c_Vat) = 1 THEN CAST(O.c_Vat AS DECIMAL(15,3)) ELSE 0 END,  
                           ISNULL(OC.noofcontainer_ord,0)   
                  ORDER BY O.Orderkey                
                 
               OPEN CURSOR_CONORDER2                                                     
                                                                                             
               FETCH NEXT FROM CURSOR_CONORDER2 INTO @c_Orderkey, @n_noofpallet_ord, @n_noofcontainer_ord  
                                                                                        
              WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
               BEGIN  
                  SET @n_TotFullCartonVol = 0.00  
                  SET @n_TotFullCartonGrossWgt = 0.00   
                  SET @n_TotFullCartonNetWgt = 0.00  
                  SET @n_TotFullCarton = 0  
                  SET @n_TotLooseCartonVol = 0.00  
                  SET @n_TotLooseCartonGrossWgt = 0.00   
                  SET @n_TotLooseCartonNetWgt = 0.00  
                  SET @n_TotLooseCarton = 0  
                  SET @n_TotCarton = 0  
                    
                  TRUNCATE TABLE #TMP_PICK  
                    
                  INSERT INTO #TMP_PICK (Sku, OrderLineNumber, Qty)  
                  SELECT Sku, OrderLineNumber, SUM(Qty)  
                  FROM PICKDETAIL(NOLOCK)  
                  WHERE Orderkey = @c_Orderkey  
                  AND Status >= '5'  
                  GROUP BY Sku, OrderLineNumber  
                    
                  --Get used qty for the order  
                  --loop consignee->container->order  
                  DECLARE CURSOR_EXTORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                     SELECT OrderLineNumber, SUM(CASE WHEN ISNUMERIC(Userdefine03) = 1 THEN CAST(Userdefine03 AS INT) ELSE 0 END)   
                     FROM EXTERNORDERSDETAIL (NOLOCK)  
                     WHERE Orderkey = @c_Orderkey    
                     GROUP BY OrderLineNumber                     
  
                  OPEN CURSOR_EXTORD                                                     
                                                                                                
                  FETCH NEXT FROM CURSOR_EXTORD INTO @c_OrderLineNumber, @n_Qty  
                                                                                           
                  WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
                  BEGIN                 
                    UPDATE #TMP_PICK  
                    SET Qty = Qty - @n_Qty  --deduct used qty   
                    WHERE OrderLineNumber = @c_OrderLineNumber  
                                
                     FETCH NEXT FROM CURSOR_EXTORD INTO @c_OrderLineNumber, @n_Qty  
                  END  
                  CLOSE CURSOR_EXTORD  
                  DEALLOCATE CURSOR_EXTORD  
                                       
                  --calculate total pallet  
                  SET @n_TotPallet = ROUND((@n_noofpallet_ord / (@n_noofcontainer_ord * 1.0)), 3)    
                    
                  --calculate total pallet volume  
                  SET @n_TotPalletVol = ROUND(@n_TotPallet * @n_PalletVolume, 6)   
                    
                  SET @c_NewDeliveryNo = ''  
                  IF @n_noofcontainer_ord > 1  
                  BEGIN  
                     EXEC dbo.nspg_GetKey                  
                       @KeyName = 'LEGO_NEWNO'      
                      ,@fieldlength = 10      
                      ,@keystring = @c_NewDeliveryNo OUTPUT      
                      ,@b_Success = @b_success OUTPUT      
                      ,@n_err = @n_err OUTPUT      
                      ,@c_errmsg = @c_errmsg OUTPUT  
                     ,@b_resultset = 0      
                     ,@n_batch     = 1  
                       
                     SET @c_NewDeliveryNo = LTRIM(RTRIM(CAST(CAST(@c_NewDeliveryNo AS BIGINT) AS NVARCHAR)))  
                  END                   
                    
                  --calculate total carton  
                  SELECT @n_TotCarton = COUNT(DISTINCT PD.LabelNo)  
                  FROM MBOLDETAIL MD (NOLOCK)                                                    
                  JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey                             
                  JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey                        
                  JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno                   
                  JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID                      
                  JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey             
                  WHERE MD.Mbolkey = @c_Mbolkey                                                  
                  AND CTD.Containerkey = @c_Containerkey                                         
                  AND O.Orderkey = @c_Orderkey                      
                    
                  --calculate distribute pallet volume  
                  SET @n_DistributePltVol = ROUND(@n_TotPalletVol / @n_TotCarton, 6)                            
                    
                  --calculate distribute pallet weight  
                  SET @n_DistributePltWgt = ROUND(@n_TotPalletGrossWgt / @n_TotCarton, 6) --NJOW05                           
                                                           
                  --calculate total full carton & volume * grosswgt & netwgt         
                  --loop consignee->container->order->label                  
                  DECLARE CURSOR_ORDFULLCARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
                     SELECT PD.LabelNo, ROUND(MAX(Sku.Cube),6) AS CtnVolume, ROUND(MAX(Sku.Grosswgt),6) AS CtnGrossWgt, ROUND(MAX(Sku.NetWgt),6) AS CtnNetWgt                           
                     FROM MBOLDETAIL MD (NOLOCK)                                                    
                     JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey                             
                     JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey                        
                     JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno                   
                     JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku         
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey                               
                     JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID                      
                     JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey             
                     WHERE MD.Mbolkey = @c_Mbolkey                                                  
                     AND CTD.Containerkey = @c_Containerkey                                         
                     AND O.Orderkey = @c_Orderkey                                                  
                     GROUP BY PD.LabelNo                                                            
                     HAVING COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) = MAX(PACK.Casecnt)               
                     ORDER BY PD.LabelNo                                                            
                 
                  OPEN CURSOR_ORDFULLCARTON                                                     
                                                                                                
                  FETCH NEXT FROM CURSOR_ORDFULLCARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
                                                                                           
                  WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
                  BEGIN        
                     SET @n_TotFullCartonVol = @n_TotFullCartonVol + @n_CartonVol  
                     SET @n_TotFullCartonGrossWgt = @n_TotFullCartonGrossWgt + @n_CartonGrossWgt  
                     SET @n_TotFullCartonNetWgt = @n_TotFullCartonNetWgt + @n_CartonNetWgt  
                     SET @n_TotFullCarton =  @n_TotFullCarton + 1  
                       
                     --Insert detail  
                     SET @c_CallSource = 'FULLCARTON_STC'  
                     GOTO INSERT_EXTERNORDERSDETAIL  
                       
                     FULLCARTON_STC_RTN:  
                       
                      FETCH NEXT FROM CURSOR_ORDFULLCARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
                  END   
                  CLOSE CURSOR_ORDFULLCARTON  
                  DEALLOCATE CURSOR_ORDFULLCARTON            
                    
                  --calculate total loose carton & volume * grosswgt & netwgt         
                  --loop consignee->container->order->label                  
                  DECLARE CURSOR_ORDLOOSECARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR               
                     SELECT PD.LabelNo, ROUND(SUM(SKU.StdCube * PD.Qty),6) AS LooseCtnVolume, ROUND(SUM(SKU.StdGrossWgt * PD.Qty),6)  AS LooseCtnGrossWgt,   
                            ROUND(SUM(SKU.StdNetWgt * PD.Qty),6)  AS LooseCtnNetWgt   
                     FROM MBOLDETAIL MD (NOLOCK)  
                     JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                     JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                     JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                     JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
                     JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
                     JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
                     JOIN CONTAINERDETAIL CTD (NOLOCK) ON PLD.Palletkey = CTD.Palletkey  
                     WHERE MD.Mbolkey = @c_Mbolkey  
                     AND CTD.Containerkey = @c_Containerkey  
                     AND O.Orderkey = @c_Orderkey              
                     GROUP BY PD.LabelNo  
                     HAVING COUNT(DISTINCT PD.Sku) > 1 OR (COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) <> MAX(PACK.Casecnt))  
                     ORDER BY PD.LabelNo                                                                                  
                 
                  OPEN CURSOR_ORDLOOSECARTON                                                     
                                                                                                
                  FETCH NEXT FROM CURSOR_ORDLOOSECARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
                                                                                           
                  WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
                  BEGIN        
                     SET @n_TotLooseCartonVol = @n_TotLooseCartonVol + @n_CartonVol  
                     SET @n_TotLooseCartonGrossWgt = @n_TotLooseCartonGrossWgt + @n_CartonGrossWgt  
                     SET @n_TotLooseCartonNetWgt = @n_TotLooseCartonNetWgt + @n_CartonNetWgt  
                     SET @n_TotLooseCarton =  @n_TotLooseCarton + 1  
                       
                     --Insert detail  
                     SET @c_CallSource = 'LOOSECARTON_STC'  
                     GOTO INSERT_EXTERNORDERSDETAIL  
                       
                     LOOSECARTON_STC_RTN:  
                       
                      FETCH NEXT FROM CURSOR_ORDLOOSECARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
                  END   
                  CLOSE CURSOR_ORDLOOSECARTON  
                  DEALLOCATE CURSOR_ORDLOOSECARTON            
                    
                  SET @n_TotOrderVol = @n_TotPalletVol + @n_TotFullCartonVol + @n_TotLooseCartonVol         
                  SET @n_TotOrderGrossWgt = @n_TotPalletGrossWgt + @n_TotFullCartonGrossWgt + @n_TotLooseCartonGrossWgt  
                  SET @n_TotOrderNetWgt = @n_TotFullCartonNetWgt + @n_TotLooseCartonNetWgt  
                  SET @n_TotOrderCarton = @n_TotFullCarton + @n_TotLooseCarton  
                  SET @n_OrderFreightAmt = ROUND(@n_FreightAmt * (@n_TotOrderVol / @n_TotContainerVol),2)  --ROUND(@n_FreightAmt / @n_TotOrderVol,2)  
                  SET @n_FreightSurcharge = @n_OrderFreightAmt * @n_SurChargeRate  
                  SET @n_Vat = (@n_OrderFreightAmt + @n_FreightSurcharge) * @n_VATRate  --NJOW03  
                  SET @c_RateString = FORMAT(@n_TotOrderGrossWgt,'0.######') + '|' + FORMAT(@n_TotOrderNetWgt,'0.######') + '|' + FORMAT(@n_TotPallet,'0.######')                                     
                    
                  INSERT INTO EXTERNORDERS (ExternOrderkey, Orderkey, Storerkey, Source, PlatformName, PlatformOrderNo, Userdefine01,   
                          Userdefine02, Userdefine03, Userdefine04, Userdefine05, Userdefine06, userdefine07, userdefine08, userdefine09, userdefine10)  
                  VALUES (CAST(@n_ShipmentNo AS NVARCHAR), @c_Orderkey, @c_Storerkey, @c_Containerkey, @c_RateString, @c_Consigneekey, FORMAT(@n_TotOrderVol,'0.######'),  
                          CAST(@n_TotFullCarton AS NVARCHAR), CAST(@n_TotLooseCarton AS NVARCHAR), FORMAT(@n_TotFullCartonVol,'0.######'),   
                          FORMAT(@n_TotLooseCartonVol,'0.######'), FORMAT(@n_OrderFreightAmt,'0.00'), FORMAT(@n_FreightSurcharge,'0.00'),  
                          FORMAT(@n_Vat,'0.00'),  @c_NewDeliveryNo,  @c_Mbolkey)                            
                    
                  FETCH NEXT FROM CURSOR_CONORDER2 INTO @c_Orderkey, @n_noofpallet_ord, @n_noofcontainer_ord  
               END           
               CLOSE CURSOR_CONORDER2  
               DEALLOCATE CURSOR_CONORDER2               
            END   
                        
            FETCH NEXT FROM CURSOR_CONSCONTAINER INTO @c_Containerkey        
         END  
         CLOSE CURSOR_CONSCONTAINER  
         DEALLOCATE CURSOR_CONSCONTAINER         
         
         FETCH NEXT FROM CURSOR_CONSIGNEE INTO @c_Consigneekey, @c_Zone, @n_ZoneMaxRate, @n_ExportOrdCnt, @n_HK_MoExportOrdCnt        
      END  
      CLOSE CURSOR_CONSIGNEE  
      DEALLOCATE CURSOR_CONSIGNEE                     
   END  
  
   --7 Process for consignee without scan to container --NJOW01   
   IF @n_continue IN(1,2)  
   BEGIN                   
      --loop consignee  
      DECLARE CURSOR_CONSIGNEE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT O.Consigneekey, ISNULL(Z.Long,'') AS Zone,  
                CASE WHEN ISNUMERIC(Z.Short) = 1 THEN CAST(Z.Short AS DECIMAL(15,2)) ELSE 0 END,  --NJOW01           
                SUM(CASE WHEN ISNULL(O.C_Country,'') <> ISNULL(S.Country,'') THEN 1 ELSE 0 END), --NJOW02  
                SUM(CASE WHEN ISNULL(O.C_Country,'') ='MO' AND ISNULL(S.Country,'') = 'HK' THEN 1 ELSE 0 END) --NJOW03                                  
         FROM MBOLDETAIL MD (NOLOCK)  
         JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey --NJOW02  
         JOIN STORER S (NOLOCK) ON O.Storerkey = S.Storerkey  
         OUTER APPLY (SELECT TOP 1 CL.Long, CL.Short FROM CODELKUP CL (NOLOCK) WHERE CL.Listname = 'CUSTPARAM' AND CL.Code = 'FMS_ZONE'   
                      AND CAST(CL.UDF01 AS BIGINT) <= CAST(CASE WHEN ISNUMERIC(O.C_Zip) = 1 THEN O.C_Zip ELSE 1 END AS BIGINT)   
                      AND CAST(CL.UDF02 AS BIGINT) >= CAST(CASE WHEN ISNUMERIC(O.C_Zip) = 1 THEN O.C_Zip ELSE 1 END AS BIGINT)) AS Z  
         JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
         JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
         LEFT JOIN PALLETDETAIL PLD (NOLOCK) ON PD.LabelNo = PLD.CaseID  
         WHERE MD.Mbolkey = @c_Mbolkey  
         --AND PLD.PalletKey IS NULL  
         AND O.Consigneekey NOT IN(SELECT DISTINCT O.Consigneekey        
                                   FROM MBOLDETAIL MD (NOLOCK)  
                                   JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                                   JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                                   JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                                   JOIN PALLETDETAIL PLD(NOLOCK) ON PD.LabelNo = PLD.CaseID  
                                   JOIN CONTAINERDETAIL CD (NOLOCK) ON PLD.Palletkey = CD.PalletKey   
                                   WHERE MD.Mbolkey = @c_Mbolkey)  
         GROUP BY O.Consigneekey, ISNULL(Z.Long,''),  
                  CASE WHEN ISNUMERIC(Z.Short) = 1 THEN CAST(Z.Short AS DECIMAL(15,2)) ELSE 0 END  --NJOW01     
         ORDER BY O.Consigneekey                
        
      OPEN CURSOR_CONSIGNEE  
        
      FETCH NEXT FROM CURSOR_CONSIGNEE INTO @c_Consigneekey, @c_Zone, @n_ZoneMaxRate, @n_ExportOrdCnt, @n_HK_MOExportOrdCnt    
        
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
      BEGIN                                 
         SET @n_Totpallet = 0.00  
         SET @n_Totpalletvol = 0.00  
         SET @n_TotPalletGrossWgt = 0.00  
         SET @n_TotFullCarton = 0   
         SET @n_TotFullCartonVol = 0.00   
         SET @n_TotLooseCarton = 0   
         SET @n_TotLooseCartonVol = 0.00  
         SET @n_TotConsigneeCarton = 0  
         SET @n_TotConsigneeVol = 0.00  
           
         --NJOW03  
        IF @n_HK_MOExportOrdCnt > 0    
        BEGIN  
           SET @c_Zone = 'MOEXPORT'  
        END  
        ELSE IF @n_ExportOrdCnt > 0     
        BEGIN  
           SET @c_Zone = 'NA'  
           SET @n_ZoneMaxRate = 1  
        END           
          
        --------------create freight by consignee----------------    
        IF @n_continue IN(1,2)  
        BEGIN  
            --calculate total pallet & volume          
            SELECT @n_Totpallet = SUM(CASE WHEN ISNUMERIC(O.c_Vat) = 1 THEN CAST(O.c_Vat AS DECIMAL(15,3)) ELSE 0 END)                           
            FROM MBOLDETAIL MD (NOLOCK)  
            JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
            WHERE MD.Mbolkey = @c_Mbolkey  
            AND O.Consigneekey = @c_Consigneekey  
             
           SET @n_totpalletvol = ROUND(@n_totpallet * @n_PalletVolume, 6)   
                         
            --calculate total full carton & volume       
            --loop consignee->label                  
            DECLARE CURSOR_CONSFULLCARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
               SELECT PD.LabelNo, ROUND(MAX(Sku.Cube),6) AS CtnVolume                         
               FROM MBOLDETAIL MD (NOLOCK)                                                    
               JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey                             
               JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey                        
               JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno                   
               JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku         
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey                               
               WHERE MD.Mbolkey = @c_Mbolkey                                                  
               AND O.Consigneekey = @c_Consigneekey                                                  
               GROUP BY PD.LabelNo                                                            
               HAVING COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) = MAX(PACK.Casecnt)               
               ORDER BY PD.LabelNo                                                            
              
            OPEN CURSOR_CONSFULLCARTON                                                     
                                                                                          
            FETCH NEXT FROM CURSOR_CONSFULLCARTON INTO @c_LabelNo, @n_CartonVol  
                                                                                     
            WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
            BEGIN        
               SET @n_TotFullCartonVol = @n_TotFullCartonVol + @n_CartonVol  
               SET @n_TotFullCarton =  @n_TotFullCarton + 1  
                             
               FETCH NEXT FROM CURSOR_CONSFULLCARTON INTO @c_LabelNo, @n_CartonVol  
            END   
            CLOSE CURSOR_CONSFULLCARTON  
            DEALLOCATE CURSOR_CONSFULLCARTON                
              
            --calculate total loose carton & volume       
            --loop consignee->label                  
            DECLARE CURSOR_CONSLOOSECARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
       SELECT PD.LabelNo, ROUND(SUM(SKU.StdCube * PD.Qty),6) AS CtnVolume                         
               FROM MBOLDETAIL MD (NOLOCK)                                                    
               JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey                             
               JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey                        
               JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno                   
               JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku         
               JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey                               
               WHERE MD.Mbolkey = @c_Mbolkey                                                  
               AND O.Consigneekey = @c_Consigneekey                                                  
               GROUP BY PD.LabelNo                                                            
               HAVING COUNT(DISTINCT PD.Sku) > 1 OR (COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) <> MAX(PACK.Casecnt))            
               ORDER BY PD.LabelNo                                                            
              
            OPEN CURSOR_CONSLOOSECARTON                                                     
                                                                                          
            FETCH NEXT FROM CURSOR_CONSLOOSECARTON INTO @c_LabelNo, @n_CartonVol  
                                                                                     
            WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
            BEGIN        
               SET @n_TotLooseCartonVol = @n_TotLooseCartonVol + @n_CartonVol  
               SET @n_TotLooseCarton =  @n_TotLooseCarton + 1  
                             
               FETCH NEXT FROM CURSOR_CONSLOOSECARTON INTO @c_LabelNo, @n_CartonVol  
            END   
            CLOSE CURSOR_CONSLOOSECARTON  
            DEALLOCATE CURSOR_CONSLOOSECARTON              
              
            --Calculate total consignee carton & volume  
            SET @n_TotConsigneeCarton = @n_TotFullCarton + @n_TotLooseCarton  
            SET @n_TotConsigneeVol = @n_totpalletvol + @n_TotFullCartonVol + @n_TotLooseCartonVol  
            --SET @n_TotConsigneeVolRounded = CASE WHEN (@n_TotConsigneeVol - ROUND(@n_TotConsigneeVol,2,1)) > 0 THEN ROUND(@n_TotConsigneeVol,2,1) + 0.01 ELSE ROUND(@n_TotConsigneeVol,2,1) END --NJOW02  
             
			      --NL01 S
			      SET @n_TotConsigneeVolRounded = CASE WHEN ROUND(@n_TotConsigneeVol,2) >  @n_TotConsigneeVol THEN ROUND(@n_TotConsigneeVol,2)
			      									 WHEN ROUND(@n_TotConsigneeVol,2) <= @n_TotConsigneeVol AND (ROUND(@n_TotConsigneeVol,3) - ROUND(@n_TotConsigneeVol,2)) > 0 THEN ROUND(@n_TotConsigneeVol,2,1) + 0.01 
			      									 ELSE ROUND(@n_TotConsigneeVol,2,1) END
			      --NL01 E

            --calculate freight amount  
            SET @n_FreightRate = 0.00  
            SET @c_FreightType = ''                    
            SET @n_FreightAmt = 0.00  
            SELECT TOP 1 @n_FreightRate = CASE WHEN ISNUMERIC(CL.Long) = 1 THEN CAST(CL.Long AS DECIMAL(15,4)) ELSE 0 END,  
                         @c_FreightType = CL.Short  
            FROM CODELKUP CL (NOLOCK)  
            WHERE CL.ListName = 'CUSTPARAM'  
            AND CL.Storerkey = @c_Storerkey  
            AND CL.Code = 'FMS_FRTCHARGE'  
            AND CAST(CL.UDF01 AS DECIMAL(15,4)) < @n_TotConsigneeVolRounded  
            AND CAST(CL.UDF02 AS DECIMAL(15,4)) >= @n_TotConsigneeVolRounded  
            AND CL.UDF03 = @C_Zone  
              
            --NJOW02  
            IF @n_ExportOrdCnt > 0    
               AND @n_HK_MOExportOrdCnt = 0 --NJOW03  
            BEGIN  
               SET @n_FreightRate = 1  
               SET @c_FreightType = 'FIXED'  
            END  
              
            IF @c_FreightType = 'FIXED'  
               SET @n_FreightAmt = @n_FreightRate  
            ELSE   
               SET @n_FreightAmt = ROUND(@n_TotConsigneeVolRounded * @n_FreightRate,2) --NJOW01                    
                                
            IF @n_FreightAmt > @n_ZoneMaxRate  --NJOW01  
               AND @n_HK_MOExportOrdCnt = 0 --NJOW03              
               SET @n_FreightAmt = @n_ZoneMaxRate  
                 
            SET @c_RateString = FORMAT(@n_FreightRate,'0.######') + '|' + RTRIM(@c_FreightType) + '|' + FORMAT(@n_SurchargeRate,'0.######') + '|' + FORMAT(@n_VATRate,'0.######')    
              
            /*               
            EXEC dbo.nspg_GetKey                  
                 @KeyName = 'LEGO_SHIPNO'      
                ,@fieldlength = 10      
                ,@keystring = @c_ShipmentNo OUTPUT      
                ,@b_Success = @b_success OUTPUT      
                ,@n_err = @n_err OUTPUT      
                ,@c_errmsg = @c_errmsg OUTPUT  
                ,@b_resultset = 0      
                ,@n_batch     = 1  
            */                     
                  
            INSERT INTO EXTERNORDERS (ExternOrderkey, Orderkey, Storerkey, Source, PlatformName, PlatformOrderNo, Userdefine01,   
                                      Userdefine02, Userdefine03, Userdefine04, Userdefine05, Userdefine06, userdefine07)  
                              VALUES (@c_Mbolkey, 'C999999999', @c_Storerkey, '', @c_RateString, @c_Consigneekey, FORMAT(@n_TotConsigneeVol,'0.######'),  
                                      CAST(@n_TotFullCarton AS NVARCHAR), CAST(@n_TotLooseCarton AS NVARCHAR), FORMAT(@n_TotFullCartonVol,'0.######'),   
                                      FORMAT(@n_TotLooseCartonVol,'0.######'), FORMAT(@n_FreightAmt,'0.00'), FORMAT(@n_TotPallet,'0.######'))                            
              
            SET @n_ShipmentNo = @@IDENTITY                    
        END  
          
         --------------Create freight by order----------------       
         IF @n_continue IN(1,2)  
         BEGIN  
            --loop consignee->order  
            DECLARE CURSOR_CONSORDER CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
               SELECT O.Orderkey,  
                     CASE WHEN ISNUMERIC(O.c_Vat) = 1 THEN CAST(O.c_Vat AS DECIMAL(15,3)) ELSE 0 END AS noofpallet_ord    
               FROM MBOLDETAIL MD (NOLOCK)  
               JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
               WHERE MD.Mbolkey = @c_Mbolkey  
               AND O.Consigneekey = @c_Consigneekey                 
               GROUP BY O.Orderkey,  
                        CASE WHEN ISNUMERIC(O.c_Vat) = 1 THEN CAST(O.c_Vat AS DECIMAL(15,3)) ELSE 0 END   
               ORDER BY O.Orderkey                
              
            OPEN CURSOR_CONSORDER                                                     
                                                                                          
            FETCH NEXT FROM CURSOR_CONSORDER INTO @c_Orderkey, @n_noofpallet_ord  
                                                                                     
            WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
            BEGIN  
               SET @n_TotFullCartonVol = 0.00  
               SET @n_TotFullCartonGrossWgt = 0.00   
               SET @n_TotFullCartonNetWgt = 0.00  
               SET @n_TotFullCarton = 0  
               SET @n_TotLooseCartonVol = 0.00  
               SET @n_TotLooseCartonGrossWgt = 0.00   
               SET @n_TotLooseCartonNetWgt = 0.00  
               SET @n_TotLooseCarton = 0  
               SET @n_TotCarton = 0  
                 
               TRUNCATE TABLE #TMP_PICK  
                 
               INSERT INTO #TMP_PICK (Sku, OrderLineNumber, Qty)  
               SELECT Sku, OrderLineNumber, SUM(Qty)  
               FROM PICKDETAIL(NOLOCK)  
               WHERE Orderkey = @c_Orderkey  
               AND Status >= '5'  
               GROUP BY Sku, OrderLineNumber  
  
               --Get used qty for the order  
               --loop consignee->container->order  
               DECLARE CURSOR_EXTORD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
                  SELECT OrderLineNumber, SUM(CASE WHEN ISNUMERIC(Userdefine03) = 1 THEN CAST(Userdefine03 AS INT) ELSE 0 END)   
                  FROM EXTERNORDERSDETAIL (NOLOCK)  
                  WHERE Orderkey = @c_Orderkey     
                  GROUP BY OrderLineNumber                    
  
               OPEN CURSOR_EXTORD                                                     
                                                                                      
               FETCH NEXT FROM CURSOR_EXTORD INTO @c_OrderLineNumber, @n_Qty  
                                                                                        
               WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
               BEGIN                 
                  UPDATE #TMP_PICK  
                  SET Qty = Qty - @n_Qty  --deduct used qty   
                  WHERE OrderLineNumber = @c_OrderLineNumber  
                             
                  FETCH NEXT FROM CURSOR_EXTORD INTO @c_OrderLineNumber, @n_Qty  
               END  
               CLOSE CURSOR_EXTORD  
               DEALLOCATE CURSOR_EXTORD  
                                    
              --calculate total pallet  
              SET @n_TotPallet = @n_noofpallet_ord    
                 
               --calculate total pallet volume  
               SET @n_TotPalletVol = ROUND(@n_TotPallet * @n_PalletVolume, 6)   
                 
               --calculate total pallet gross weight  
              SET @n_TotPalletGrossWgt = ROUND(@n_TotPallet * @n_PalletGrossWgt, 6)   
                 
               --calculate total carton  
               SELECT @n_TotCarton = COUNT(DISTINCT PD.LabelNo)  
               FROM MBOLDETAIL MD (NOLOCK)                                                    
               JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey                             
               JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey                        
               JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno                   
               WHERE MD.Mbolkey = @c_Mbolkey                                                  
               AND O.Orderkey = @c_Orderkey                      
                 
               --calculate distribute pallet volume  
               SET @n_DistributePltVol = ROUND(@n_TotPalletVol / @n_TotCarton, 6)                            
  
               --calculate distribute pallet weight  
               SET @n_DistributePltWgt = ROUND(@n_TotPalletGrossWgt / @n_TotCarton, 6) --NJOW05                           
                                              
               --calculate total full carton & volume * grosswgt & netwgt         
               --loop consignee->container->order->label                  
               DECLARE CURSOR_ORDFULLCARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR                       
                  SELECT PD.LabelNo, ROUND(MAX(Sku.Cube),6) AS CtnVolume, ROUND(MAX(Sku.Grosswgt),6) AS CtnGrossWgt, ROUND(MAX(Sku.NetWgt),6) AS CtnNetWgt                           
                  FROM MBOLDETAIL MD (NOLOCK)                                                    
                  JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey                             
                  JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey                        
                  JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno                   
                  JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku         
                  JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey                               
                  WHERE MD.Mbolkey = @c_Mbolkey                                                  
                  AND O.Orderkey = @c_Orderkey                                                  
                  GROUP BY PD.LabelNo                                                            
                  HAVING COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) = MAX(PACK.Casecnt)               
                  ORDER BY PD.LabelNo                                                            
              
               OPEN CURSOR_ORDFULLCARTON                                                     
                                                                                             
               FETCH NEXT FROM CURSOR_ORDFULLCARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
                                                                                        
               WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
               BEGIN        
                  SET @n_TotFullCartonVol = @n_TotFullCartonVol + @n_CartonVol  
                  SET @n_TotFullCartonGrossWgt = @n_TotFullCartonGrossWgt + @n_CartonGrossWgt  
                  SET @n_TotFullCartonNetWgt = @n_TotFullCartonNetWgt + @n_CartonNetWgt  
                  SET @n_TotFullCarton =  @n_TotFullCarton + 1  
                    
                  --Insert detail  
                  SET @c_CallSource = 'FULLCARTON_NONSTC'  
                  GOTO INSERT_EXTERNORDERSDETAIL  
                    
                  FULLCARTON_NONSTC_RTN:  
                    
                   FETCH NEXT FROM CURSOR_ORDFULLCARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
               END   
               CLOSE CURSOR_ORDFULLCARTON  
               DEALLOCATE CURSOR_ORDFULLCARTON            
                 
               --calculate total loose carton & volume * grosswgt & netwgt         
               --loop consignee->order->label                  
               DECLARE CURSOR_ORDLOOSECARTON CURSOR LOCAL FAST_FORWARD READ_ONLY FOR               
                  SELECT PD.LabelNo, ROUND(SUM(SKU.StdCube * PD.Qty),6) AS LooseCtnVolume, ROUND(SUM(SKU.StdGrossWgt * PD.Qty),6)  AS LooseCtnGrossWgt,   
                         ROUND(SUM(SKU.StdNetWgt * PD.Qty),6)  AS LooseCtnNetWgt   
                  FROM MBOLDETAIL MD (NOLOCK)  
                  JOIN ORDERS O (NOLOCK) ON MD.Orderkey = O.Orderkey  
                  JOIN PACKHEADER PH (NOLOCK) ON MD.Orderkey = PH.Orderkey  
                  JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
                  JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
                  JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
                  WHERE MD.Mbolkey = @c_Mbolkey  
                  AND O.Orderkey = @c_Orderkey              
                  GROUP BY PD.LabelNo  
                  HAVING COUNT(DISTINCT PD.Sku) > 1 OR (COUNT(DISTINCT PD.Sku) = 1 AND SUM(PD.Qty) <> MAX(PACK.Casecnt))  
                  ORDER BY PD.LabelNo                                                                                  
              
               OPEN CURSOR_ORDLOOSECARTON                                                     
                                                                                             
               FETCH NEXT FROM CURSOR_ORDLOOSECARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
                                                                                        
               WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
               BEGIN        
                  SET @n_TotLooseCartonVol = @n_TotLooseCartonVol + @n_CartonVol  
                  SET @n_TotLooseCartonGrossWgt = @n_TotLooseCartonGrossWgt + @n_CartonGrossWgt  
                  SET @n_TotLooseCartonNetWgt = @n_TotLooseCartonNetWgt + @n_CartonNetWgt  
                  SET @n_TotLooseCarton =  @n_TotLooseCarton + 1  
                    
                  --Insert detail  
                  SET @c_CallSource = 'LOOSECARTON_NONSTC'  
                  GOTO INSERT_EXTERNORDERSDETAIL  
                    
                  LOOSECARTON_NONSTC_RTN:  
                    
                   FETCH NEXT FROM CURSOR_ORDLOOSECARTON INTO @c_LabelNo, @n_CartonVol, @n_CartonGrossWgt, @n_CartonNetWgt  
               END   
               CLOSE CURSOR_ORDLOOSECARTON  
               DEALLOCATE CURSOR_ORDLOOSECARTON            
                 
               SET @n_TotOrderVol = @n_TotPalletVol + @n_TotFullCartonVol + @n_TotLooseCartonVol         
               SET @n_TotOrderGrossWgt = @n_TotPalletGrossWgt + @n_TotFullCartonGrossWgt + @n_TotLooseCartonGrossWgt  
               SET @n_TotOrderNetWgt = @n_TotFullCartonNetWgt + @n_TotLooseCartonNetWgt  
               SET @n_TotOrderCarton = @n_TotFullCarton + @n_TotLooseCarton  
               SET @n_OrderFreightAmt = ROUND(@n_FreightAmt * (@n_TotOrderVol / @n_TotConsigneeVol),2)  --ROUND(@n_FreightAmt / @n_TotOrderVol,2)  
               SET @n_FreightSurcharge = @n_OrderFreightAmt * @n_SurChargeRate  
               SET @n_Vat = (@n_OrderFreightAmt + @n_FreightSurcharge)  * @n_VATRate  --NJOW03  
               SET @c_RateString = FORMAT(@n_TotOrderGrossWgt,'0.######') + '|' + FORMAT(@n_TotOrderNetWgt,'0.######') + '|' + FORMAT(@n_TotPallet,'0.######')   
                 
               INSERT INTO EXTERNORDERS (ExternOrderkey, Orderkey, Storerkey, Source, PlatformName, PlatformOrderNo, Userdefine01,   
                       Userdefine02, Userdefine03, Userdefine04, Userdefine05, Userdefine06, userdefine07, userdefine08, userdefine10)  
               VALUES (CAST(@n_ShipmentNo AS NVARCHAR), @c_Orderkey, @c_Storerkey, '', @c_RateString, @c_Consigneekey, FORMAT(@n_TotOrderVol,'0.######'),  
                       CAST(@n_TotFullCarton AS NVARCHAR), CAST(@n_TotLooseCarton AS NVARCHAR), CAST(@n_TotFullCartonVol AS NVARCHAR),   
                       FORMAT(@n_TotLooseCartonVol,'0.######'), FORMAT(@n_OrderFreightAmt,'0.00'), FORMAT(@n_FreightSurcharge,'0.00'),  
                       FORMAT(@n_Vat,'0.00'), @c_Mbolkey)                            
                 
               FETCH NEXT FROM CURSOR_CONSORDER INTO @c_Orderkey, @n_noofpallet_ord  
            END           
            CLOSE CURSOR_CONSORDER  
            DEALLOCATE CURSOR_CONSORDER               
         END   
                             
         FETCH NEXT FROM CURSOR_CONSIGNEE INTO @c_Consigneekey, @c_Zone, @n_ZoneMaxRate, @n_ExportOrdCnt, @n_HK_MOExportOrdCnt          
      END  
      CLOSE CURSOR_CONSIGNEE  
      DEALLOCATE CURSOR_CONSIGNEE                     
   END  
  
QUIT_SP:  
   IF @n_continue = 3  -- Error Occured - Process And Return  
   BEGIN  
      SET @b_success = 0  
  
      IF @@TRANCOUNT = 1 AND @@TRANCOUNT > @n_StartTranCount  
      BEGIN  
         ROLLBACK TRAN  
      END  
      EXECUTE nsp_logerror @n_err, @c_errmsg, 'ispMBFZ03'  
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012      
      RETURN  
   END  
   ELSE  
   BEGIN  
      SET @b_success = 1  
      WHILE @@TRANCOUNT > @n_StartTranCount    
      BEGIN    
         COMMIT TRAN    
      END    
      RETURN  
   END   
  
INSERT_EXTERNORDERSDETAIL:  
   DECLARE CURSOR_PACKD CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
      SELECT PD.Sku, PD.LottableValue, SUM(PD.Qty), PACK.CaseCnt  
      FROM ORDERS O (NOLOCK)   
      JOIN PACKHEADER PH (NOLOCK) ON O.Orderkey = PH.Orderkey  
      JOIN PACKDETAIL PD (NOLOCK) ON PH.Pickslipno = PD.Pickslipno  
      JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku  
      JOIN PACK (NOLOCK) ON SKU.Packkey = PACK.Packkey  
      WHERE O.Orderkey = @c_Orderkey  
      AND PD.LabelNo = @c_Labelno  
      GROUP BY PD.Sku, PD.LottableValue, PACK.CaseCnt  
      ORDER BY PD.Sku, PD.LottableValue  
  
   OPEN CURSOR_PACKD                                                     
                                                                                                
   FETCH NEXT FROM CURSOR_PACKD INTO @c_Sku, @c_LottableValue, @n_PackQty, @n_CaseCnt  
                                                                                           
   WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2)  
   BEGIN        
      DECLARE CURSOR_ORDLINE CURSOR LOCAL FAST_FORWARD READ_ONLY FOR  
         SELECT OrderLineNumber, Qty  
         FROM #TMP_PICK  
         WHERE Sku = @c_Sku  
         AND Qty > 0  
         ORDER BY CASE WHEN Qty >= @n_CaseCnt THEN 1 ELSE 2 END, OrderLineNumber  
        
      OPEN CURSOR_ORDLINE  
  
     FETCH NEXT FROM CURSOR_ORDLINE INTO @c_OrderLineNumber, @n_Qty  
        
      WHILE (@@FETCH_STATUS <> -1) AND @n_continue IN(1,2) AND @n_PackQty > 0  
      BEGIN  
        IF @n_PackQty >= @n_Qty  
          SET @n_QtyTake = @n_Qty             
        ELSE  
           SET @n_QtyTake = @n_PackQty  
          
        SET @n_PackQty = @n_PackQty - @n_qtyTake  
          
        UPDATE #TMP_PICK  
        SET Qty = Qty - @n_QtyTake  
        WHERE Sku = @c_Sku  
        AND OrderLineNumber = @c_OrderLineNumber               
          
        INSERT INTO EXTERNORDERSDETAIL (ExternOrderkey, ExternLineNo, Orderkey, OrderLineNumber, Storerkey, Sku, QRCode, TIDNo,   
                                        Userdefine01, Userdefine02, Userdefine03, Userdefine04, Userdefine05, Userdefine06, Userdefine07)  
                                VALUES (CAST(@n_ShipmentNo AS NVARCHAR), '', @c_Orderkey, @c_OrderLineNumber, @c_Storerkey, @c_Sku, @c_Mbolkey, 'SC',   
                                        @c_LabelNo, @c_LottableValue, CAST(@n_QtyTake AS NVARCHAR), FORMAT(@n_CartonVol,'0.######'), FORMAT(@n_CartonGrossWgt,'0.######'),  
                                        FORMAT(@n_DistributePltVol,'0.######'), FORMAT(@n_DistributePltWgt,'0.######')) --NJOW05          
          
         FETCH NEXT FROM CURSOR_ORDLINE INTO @c_OrderLineNumber, @n_Qty  
      END  
      CLOSE CURSOR_ORDLINE  
      DEALLOCATE CURSOR_ORDLINE  
                  
      FETCH NEXT FROM CURSOR_PACKD INTO @c_Sku, @c_LottableValue, @n_PackQty, @n_CaseCnt  
   END  
   CLOSE CURSOR_PACKD  
   DEALLOCATE CURSOR_PACKD                 
  
IF @c_CallSource = 'FULLCARTON_STC'  
   GOTO FULLCARTON_STC_RTN  
     
IF @c_CallSource = 'LOOSECARTON_STC'  
   GOTO LOOSECARTON_STC_RTN  
  
IF @c_CallSource = 'FULLCARTON_NONSTC'  
   GOTO FULLCARTON_NONSTC_RTN  
     
IF @c_CallSource = 'LOOSECARTON_NONSTC'  
   GOTO LOOSECARTON_NONSTC_RTN  
     
END  

GO