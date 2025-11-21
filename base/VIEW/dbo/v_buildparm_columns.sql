SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* View: V_BuildParm_Columns                                            */
/* Creation Date: 2018 (initial checkin)                                */
/* Copyright: LF Logistics                                              */
/* Written by: Wan                                                      */
/*                                                                      */
/* Purpose:                                                             */
/*        :                                                             */
/* Called By:                                                           */
/*          :                                                           */
/* PVCS Version: 2.2                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 2019-12-03  Wan01    1.4   WMS-11029 - Mbol_Outbound_OTM_Add new     */
/*                            paratype                                  */
/* 2019-12-03  Wan02    1.5   SCE - WM 1) Add 'Max_Qty_Per_Load'        */
/*                            2) Add 'BUILDWAVEPARM'                    */
/* 2021-05-17  Wan03    1.6   LFWM-2788 - UAT  CNOrder parameterBuild   */
/*                            param Details - Field values not getting  */
/*                            displayed for Build types - wavebuildload */
/*                            and wavebuildmbol                         */
/* 2022-01-04  Wan04    1.7   LFWM-3279 - SCE UAT SG Order Parameter -  */
/*                            Type 'SORT' - Do not have Sku_Total_Qty as*/
/*                            in Exceed                                 */
/* 2022-01-04  Wan04    1.7   Devops Combine Script                     */
/* 2022-08-19  Wan05    1.8   LFWM-3672 - [CN] LOREAL_New Tab for order */
/*                            analysis                                  */
/* 2022-03-13  Wan06    1.9   LFWM-4007 - CN_SCE_Wave_Release add order */
/*                            parameter                                 */
/* 2023-04-17  Wan07    2.0   LFWM-3978-[CN] LULU_OrderParam_Sort by LOC*/
/* 2023-05-26  Wan08    2.1   LFWM-4297 - PROD - CN WaveParm_Sort by LOC*/
/* 2023-06-23  Wan09    2.2   LFWM-4176 - CN UAT  Split wave into loads */
/*                            based on customized SP                    */
/************************************************************************/
CREATE   VIEW [dbo].[V_BuildParm_Columns] AS
SELECT BuildParmType = 'BUILDLOADPARM'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'BUILDLOADPARM'
      ,CondType = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('StorerKey', 'SKU')
UNION ALL
SELECT BuildParmType = 'BUILDLOADPARM'
      ,CondType = 'RESTRICT'
      ,FieldName= 'Max_Orders_Per_Load'
UNION ALL
SELECT BuildParmType = 'BUILDLOADPARM'
      ,CondType = 'RESTRICT'
      ,FieldName= 'Max_Qty_Per_Load'
UNION ALL
SELECT BuildParmType = 'BUILDLOADPARM'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('SKU')
UNION ALL
SELECT BuildParmType = 'BUILDLOADPARM'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'BACKENDALLOC'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'BACKENDALLOC'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('StorerKey', 'SKU')
UNION ALL
SELECT BuildParmType = 'BACKENDALLOC'
      ,CondType = 'RESTRICT'
      ,FieldName= 'Max_Orders_Per_Load'
UNION ALL
SELECT BuildParmType = 'BACKENDALLOC'
      ,CondType = 'RESTRICT'
      ,FieldName= 'Max_Qty_Per_Load'
UNION ALL
SELECT BuildParmType = 'BACKENDALLOC'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('SKU')
UNION ALL
SELECT BuildParmType = 'BACKENDALLOC'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'RELEASEORD'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'RELEASEORD'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('StorerKey', 'SKU')
UNION ALL
SELECT BuildParmType = 'RELEASEORD'
      ,CondType = 'RESTRICT'
      ,FieldName= 'Max_Orders_Per_Load'
UNION ALL
SELECT BuildParmType = 'RELEASEORD'
      ,CondType = 'RESTRICT'
      ,FieldName= 'Max_Qty_Per_Load'
UNION ALL
SELECT BuildParmType = 'RELEASEORD'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('SKU')
UNION ALL
SELECT BuildParmType = 'RELEASEORD'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'BUILDWAVEPARM'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC', 'ORDERDETAIL')       --(Wan06)
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
--UNION ALL                                                                                  --(Wan06)
--SELECT BuildParmType = 'BUILDWAVEPARM'  
--      ,CondType = 'CONDITION'
--      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
--FROM INFORMATION_SCHEMA.COLUMNS Col
--WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
--AND Col.COLUMN_NAME IN ('StorerKey', 'SKU')
UNION ALL
SELECT BuildParmType = 'BUILDWAVEPARM'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL', 'ORDERS', 'ORDERINFO', 'PICKDETAIL')        --(Wan08)--(Wan04) - START
--AND Col.COLUMN_NAME IN ('SKU')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'BUILDWAVEPARM'
      ,CondType  = 'SORT'
      ,FieldName = 'Sku_Total_OpenQty'                                                       --(Wan04) - END
UNION ALL
SELECT BuildParmType = 'BUILDWAVEPARM'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL                                                                        --(Wan05)
SELECT BuildParmType = 'BUILDWAVEPARM'
      ,CondType  = 'EDIT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WAVE')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho','AddDate', 'ArchiveCop', 'TrafficCop', 'Status'
                           ,'BatchNo', 'TMSStatus', 'DoorBookStatus', 'ReplenishStatus', 'TMReleaseFlag')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
UNION ALL
SELECT BuildParmType = 'WAVEBUILDLOAD'                                           --(Wan09) - START
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')      
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL                                                                        
SELECT BuildParmType = 'BUILDLOADPARM'
      ,CondType = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('StorerKey', 'SKU')
UNION ALL                                                                        --(Wan09) - END                                                                                                                      
SELECT BuildParmType = 'WAVEBUILDLOAD'                                           --(Wan03)
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('SKU')
UNION ALL                                                                        --(Wan07) - START
SELECT BuildParmType = 'WAVEBUILDLOAD'                                          
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOC')                                                  --(Wan07) - END
UNION ALL
SELECT BuildParmType = 'WAVEBUILDLOAD'                                           --(Wan03)
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'WAVEBUILDMBOL'                                        --(Wan03)
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL')
AND Col.COLUMN_NAME IN ('SKU')
UNION ALL
SELECT BuildParmType = 'WAVEBUILDMBOL'                                        --(Wan03)
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERINFO','SKU','PICKDETAIL','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'EditDate', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
AND Col.TABLE_NAME + '.' + Col.COLUMN_NAME NOT IN('ORDERINFO.Adddate','ORDERINFO.Orderkey','SKU.AddDate','PICKDETAIL.AddDate','LOC.AddDate')
UNION ALL
SELECT BuildParmType = 'OTM-ASN'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('RECEIPT')                                           -- (Wan01)
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'OTM-ASN'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('RECEIPTDETAIL', 'SKU')
AND Col.COLUMN_NAME IN ('SKU')
UNION ALL
SELECT BuildParmType = 'OTM-ASN'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('RECEIPT','RECEIPTDETAIL','SKU','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho','AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
UNION ALL
SELECT BuildParmType = 'OTM-ORD'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS')                                            -- (Wan01)
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'OTM-ORD'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERDETAIL', 'PICKDETAIL', 'SKU')
UNION ALL
SELECT BuildParmType = 'OTM-ORD'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('ORDERS','ORDERDETAIL','PICKDETAIL','SKU','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
UNION ALL
SELECT BuildParmType = 'OTM-LP'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN','ORDERS')                                 --(Wan01)
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'OTM-LP'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN','LOADPLANDETAIL','ORDERDETAIL','PICKDETAIL','SKU')
UNION ALL
SELECT BuildParmType = 'OTM-LP'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN', 'LOADPLANDETAIL','ORDERS','ORDERDETAIL','PICKDETAIL','SKU','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
UNION ALL
--(Wan02) - START
SELECT BuildParmType = 'OTM-CLP'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'OTM-CLP'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN','LOADPLANDETAIL','ORDERDETAIL','PICKDETAIL','SKU')
UNION ALL
SELECT BuildParmType = 'OTM-CLP'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('LOADPLAN', 'LOADPLANDETAIL','ORDERS','ORDERDETAIL','PICKDETAIL','SKU','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
--(Wan02) - END
UNION ALL
SELECT BuildParmType = 'OTM-WAV'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WAVE','LOADPLAN','ORDERS')                          -- (Wan01)
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'OTM-WAV'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WAVE','WAVEDETAIL','LOADPLAN','LOADPLANDETAIL','ORDERDETAIL','PICKDETAIL','SKU')
UNION ALL
SELECT BuildParmType = 'OTM-WAV'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('WAVE','WAVEDETAIL','LOADPLAN', 'LOADPLANDETAIL','ORDERS','ORDERDETAIL','PICKDETAIL','SKU','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
UNION ALL
SELECT BuildParmType = 'OTM-MBL'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','ORDERS')                                     -- (Wan01)
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'OTM-MBL'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','MBOLDETAIL','LOADPLAN','LOADPLANDETAIL','ORDERDETAIL','PICKDETAIL','SKU')
UNION ALL
SELECT BuildParmType = 'OTM-MBL'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','MBOLDETAIL','LOADPLAN', 'LOADPLANDETAIL','ORDERS','ORDERDETAIL','PICKDETAIL','SKU','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')
UNION ALL
SELECT BuildParmType = 'OTM-MBLUPD'
      ,CondType  = 'CONDITION'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','ORDERS')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
UNION ALL
SELECT BuildParmType = 'OTM-MBLUPD'
      ,CondType  = 'SORT'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','MBOLDETAIL','LOADPLAN','LOADPLANDETAIL','ORDERDETAIL','PICKDETAIL','SKU')
UNION ALL
SELECT BuildParmType = 'OTM-MBLUPD'
      ,CondType  = 'GROUP'
      ,FieldName= UPPER(Col.TABLE_NAME + '.' + Col.COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS Col
WHERE Col.TABLE_NAME IN ('MBOL','MBOLDETAIL','LOADPLAN', 'LOADPLANDETAIL','ORDERS','ORDERDETAIL','PICKDETAIL','SKU','LOC')
AND Col.COLUMN_NAME NOT IN ('EditWho', 'AddWho', 'ArchiveCop', 'TrafficCop')
AND Col.Data_Type IN ('char', 'nvarchar', 'varchar','datetime')

GO