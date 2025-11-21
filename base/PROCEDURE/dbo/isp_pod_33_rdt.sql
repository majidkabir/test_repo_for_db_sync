SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Stored Proc: isp_POD_33_rdt                                          */
/* Creation Date: 02-MAR-2023                                           */
/* Copyright: LF Logistics                                              */
/* Written by: CSCHONG                                                  */
/*                                                                      */
/* Purpose: WMS-21854 - [CN] FungKids_POD                               */
/*        :                                                             */
/* Called By: r_dw_pod_33_rdt                                           */
/*          :                                                           */
/* PVCS Version: 1.0                                                    */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver Purposes                                  */
/* 02-MAR-2023  CSCHONG   1.0 Devops Scripts Combine                    */
/* 07-APR-2023  CSCHONG   1.1 WMS-22182 add new field (CS01)            */
/* 20-Apr-2023  CSCHONG   1.2 WMS-22182 change parameter (CS02)         */
/************************************************************************/
CREATE   PROC [dbo].[isp_POD_33_rdt]
           --@c_mbolkey       NVARCHAR(20)       --CS02
             @c_palletid      NVARCHAR(30)       --CS02 

AS
BEGIN
   SET NOCOUNT ON
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE  
           @n_StartTCnt       INT
         , @n_Continue        INT 
         , @n_ttlCtn          INT

   SET @n_StartTCnt = @@TRANCOUNT

   WHILE @@TRANCOUNT > 0
   BEGIN
      COMMIT TRAN
   END


   CREATE TABLE #TMP_POD33RDT
      (  RowID          INT IDENTITY (1,1) NOT NULL 
      ,  PrintDate      NVARCHAR(16)   NULL  DEFAULT('') 
      ,  ExtmbolKey     NVARCHAR(30)   NULL  DEFAULT('')
      ,  EditDate       NVARCHAR(16)   NULL  DEFAULT('') 
      ,  Orderkey       NVARCHAR(10)   NULL  DEFAULT('') 
      ,  shipperkey     NVARCHAR(20)   NULL  DEFAULT('')
      ,  mbolkey        NVARCHAR(20)   NULL  DEFAULT('')
      ,  editwho        NVARCHAR(128)   NULL  DEFAULT('')
      ,  trackingno     NVARCHAR(20)   NULL  DEFAULT('')
      ,  TTLCTN         FLOAT   NULL  DEFAULT(0)
      ,  C_City         NVARCHAR(18)   NULL  DEFAULT('') 
      ,  casecnt        INT            NULL  DEFAULT(0)
      ,  MBWGT          FLOAT          NULL  DEFAULT(0)
      ,  Storerkey      NVARCHAR(20)   NULL  DEFAULT('') 
      ,  C_State        NVARCHAR(18)   NULL  DEFAULT('')    
      ,  MBDWGT         FLOAT    NULL  DEFAULT(0)
      ,  MBDCUBE        FLOAT    NULL  DEFAULT(0)          --CS01
      ) 
INSERT INTO #TMP_POD33RDT
(
    PrintDate,
    ExtmbolKey,
    EditDate,
    Orderkey,
    shipperkey,
    mbolkey,
    editwho,
    trackingno,
    TTLCTN,
    C_City,
    casecnt,
    MBWGT,
    Storerkey,
    C_State,
    MBDWGT,MBDCUBE                  --CS01
)
   SELECT PrintDate = Convert(NVARCHAR(16),GETDATE(),121)
         ,mb.ExternMbolKey
         ,Convert(NVARCHAR(16),mb.EditDate,121)   
         ,O.Orderkey 
         ,o.ShipperKey
         ,o.MBOLKey
         ,mb.EditWho
         ,o.TrackingNo
         ,md.TotalCartons
         ,C_City   = ISNULL(RTRIM(o.c_city),'')
         ,mb.CaseCnt
         ,mb.Weight
         ,O.storerkey 
         ,c_State      = ISNULL(RTRIM(O.C_State),'')
         ,md.Weight
         ,md.Cube            --CS01
   FROM dbo.ORDERS o WITH (NOLOCK)
   JOIN dbo.mbol mb WITH (NOLOCK) ON mb.mbolkey = o.MBOLKey
   JOIN dbo.mboldetail md WITH (NOLOCK) ON md.mbolkey = mb.MbolKey  AND md.OrderKey = o.OrderKey  --CS01 
   JOIN dbo.PALLETDETAIL PLD WITH (NOLOCK) ON PLD.UserDefine01=o.OrderKey                         --CS02 S  
   --WHERE o.MBOLKey=@c_mbolkey
   WHERE PLD.PalletKey = @c_palletid                                                              --CS02 E   
   ORDER BY O.Orderkey



      
  SELECT
   tp.PrintDate,
   tp.ExtmbolKey,
   tp.EditDate,
   tp.Orderkey,
   tp.shipperkey,
   tp.mbolkey,
   tp.Editwho,
   tp.trackingno,
   tp.TTLCTN,
   tp.C_City,
   tp.casecnt,
   tp.MBWGT,
   tp.Storerkey,
   tp.C_State,
   tp.MBDWGT,
    tp.MBDCUBE     --CS01
  FROM #TMP_POD33RDT AS tp
  ORDER BY tp.Orderkey

   WHILE @@TRANCOUNT < @n_StartTCnt
   BEGIN
      BEGIN TRAN
   END
END -- procedure

GO