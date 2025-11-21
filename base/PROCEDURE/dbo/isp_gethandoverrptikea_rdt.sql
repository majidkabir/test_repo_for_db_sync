SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_GetHandoverRptIKEA_RDT                              */
/* Creation Date: 06-Apr-2020                                           */
/* Copyright: LF Logistics                                              */
/* Written by: WLChooi                                                  */
/*                                                                      */
/* Purpose: WMS-12788 - IKEA Handover Report                            */
/*        :                                                             */
/* Called By: r_dw_handover_rpt_IKEA_rdt                                */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Version: 7.0                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date        Author   Ver   Purposes                                  */
/* 03-MAR-2023 CSCHONG  1.1   DEvops Scripts Combine & WMS-21879 (CS01) */
/************************************************************************/
CREATE   PROC isp_GetHandoverRptIKEA_RDT
         @c_sourcekey      NVARCHAR(50)
             
AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @c_mbolkey        NVARCHAR(10) = '',
           @c_extmbolkey     NVARCHAR(50) = ''

   DECLARE @n_NoOfLine       INT    
          ,@c_getstorerkey   NVARCHAR(10)    
          ,@c_getLoadkey     NVARCHAR(20)    
          ,@c_getOrderkey    NVARCHAR(20)    
          ,@c_getExtOrderkey NVARCHAR(20)  
          
   DECLARE @b_Success        INT
         , @n_Err            INT
         , @n_Continue       INT
         , @n_StartTCnt      INT
         , @c_ErrMsg         NVARCHAR(250)
         , @c_UserId         NVARCHAR(30)
         , @n_cnt            INT
         , @c_Getprinter     NVARCHAR(10) 
         , @n_MaxRowID       INT
         , @n_MaxLine        INT

   SET @b_Success   = 1
   SET @n_Err       = 0
   SET @n_Continue  = 1
   SET @n_StartTCnt = @@TRANCOUNT
   SET @c_ErrMsg    = ''
   SET @c_UserId    = SUSER_SNAME() 
   SET @n_MaxLine   = 40
   
   CREATE TABLE #Handover_RPT(
      rowid           INT NOT NULL identity(1,1),
      Shipperkey      NVARCHAR(15) NULL,
      Mbolkey         NVARCHAR(10) NULL,
      Externmbolkey   NVARCHAR(30) NULL,
      M_Company       NVARCHAR(45) NULL,
      Userdefine01    NVARCHAR(30) NULL,
      CaseId          NVARCHAR(20) NULL,
      STSUSR1         NVARCHAR(20) NULL       --CS01
   )

   IF EXISTS (SELECT 1 FROM MBOL (NOLOCK) WHERE MBOLKEY = @c_sourcekey)
      SET @c_mbolkey = @c_sourcekey 
   ELSE 
      SET @c_extmbolkey = @c_sourcekey

      INSERT INTO #Handover_RPT
      SELECT CASE WHEN ISNULL(C.short,'')='Y'  AND LEFT(OH.Shipperkey,2) = 'SF' THEN LEFT(OH.Shipperkey,2) ELSE OH.Shipperkey END AS shipperkey,   --CS01
             OH.Mbolkey,
             MBOL.Externmbolkey,
             OH.M_Company,
             PLTD.Userdefine01,
             LTRIM(RTRIM(ISNULL(PLTD.CaseId,''))),
             CASE WHEN ISNULL(C.short,'')='Y' THEN ISNULL(ST.SUSR1,'') ELSE 'IKEA CPU 037' END      --CS01
      FROM ORDERS OH (NOLOCK)    
      JOIN MBOL (NOLOCK) ON ( OH.Mbolkey = Mbol.Mbolkey )   
      JOIN PALLETDETAIL PLTD (NOLOCK) ON (PLTD.Palletkey = MBOL.ExternMbolKey) AND (PLTD.Userdefine01 = OH.Orderkey)
      JOIN PALLET PLT (NOLOCK) ON (PLT.Palletkey = PLTD.Palletkey)
      JOIN STORER ST WITH (NOLOCK) ON ST.StorerKey = OH.StorerKey     --CS01 S
      LEFT JOIN dbo.CODELKUP C WITH (NOLOCK) ON C.listname = 'REPORTCFG' and C.Code = 'SHOWFIELD'
                                        AND C.Long = 'r_dw_handover_rpt_IKEA_rdt' AND c.Storerkey = OH.StorerKey
      WHERE OH.Mbolkey = CASE WHEN @c_mbolkey <> '' THEN @c_mbolkey ELSE OH.Mbolkey END 
        AND Externmbolkey = CASE WHEN @c_extmbolkey <> '' THEN @c_extmbolkey ELSE Externmbolkey END     
        --AND (PLT.[Status] = '9' OR MBOL.[Status] >= '5')  
      GROUP BY OH.Shipperkey,
               OH.Mbolkey,
               MBOL.Externmbolkey,
               OH.M_Company,
               PLTD.Userdefine01,
               LTRIM(RTRIM(ISNULL(PLTD.CaseId,''))), ISNULL(ST.SUSR1,''),ISNULL(C.short,'')      --CS01
      
      SELECT Shipperkey    
           , Mbolkey       
           , Externmbolkey 
           , M_Company
           , Userdefine01      
           , CaseId  
           , (SELECT COUNT(DISTINCT CaseId) FROM #Handover_RPT) AS TotalCase
           , (SELECT COUNT(DISTINCT Userdefine01) FROM #Handover_RPT) AS TotalOrder
           , (Row_Number() OVER (PARTITION BY Mbolkey Order By Mbolkey, Externmbolkey, Userdefine01, 
              CASE WHEN SUBSTRING(CaseId,1,2) = 'JD' THEN
                 CASE WHEN ISNUMERIC(SUBSTRING(CaseId,CHARINDEX('-', CaseId) + 1,CHARINDEX('-', CaseId) + 2)) = 1 THEN
                    CAST(SUBSTRING(CaseId,CHARINDEX('-', CaseId) + 1,CHARINDEX('-', CaseId) + 2) AS INT) END END
             , CaseId ASC) - 1 ) / @n_MaxLine AS PageGroup
           , CAST((SELECT COUNT(t.CaseID) FROM #Handover_RPT t WHERE t.Userdefine01 = #Handover_RPT.Userdefine01) AS NVARCHAR(10)) AS TotalCasePerUserdefine01
           , CAST((Row_Number() OVER (PARTITION BY Userdefine01 Order By Mbolkey, Externmbolkey, Userdefine01, 
              CASE WHEN SUBSTRING(CaseId,1,2) = 'JD' THEN
                 CASE WHEN ISNUMERIC(SUBSTRING(CaseId,CHARINDEX('-', CaseId) + 1,CHARINDEX('-', CaseId) + 2)) = 1 THEN
                    CAST(SUBSTRING(CaseId,CHARINDEX('-', CaseId) + 1,CHARINDEX('-', CaseId) + 2) AS INT) END END
          , CaseId ASC) ) AS NVARCHAR(10)) AS CaseIDCount
          , STSUSR1 AS STSUSR1                 --CS01
      FROM #Handover_RPT
      ORDER BY Externmbolkey, Userdefine01
             , CASE WHEN SUBSTRING(CaseId,1,2) = 'JD' THEN
                  CASE WHEN ISNUMERIC(SUBSTRING(CaseId,CHARINDEX('-', CaseId) + 1,CHARINDEX('-', CaseId) + 2)) = 1 THEN
                     CAST(SUBSTRING(CaseId,CHARINDEX('-', CaseId) + 1,CHARINDEX('-', CaseId) + 2) AS INT) END END
             , CaseId ASC

QUIT_SP:
END -- procedure

GO