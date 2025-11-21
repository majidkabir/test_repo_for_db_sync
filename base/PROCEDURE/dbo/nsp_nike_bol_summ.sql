SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
/************************************************************************/
/* Store Procedure:  nsp_Nike_BOL_Summ                            		*/
/* Creation Date:                                     						*/
/* Copyright: IDS                                                       */
/* Written by:                                                 			*/
/*                                                                      */
/* Purpose:  BOL Summary Report                                         */
/*                                                                      */
/* Usage:  Used for report dw = r_dw_bol_summ_nikecn                    */
/*                                                                      */
/* Called By: Exceed                                      					*/
/*                                                                      */
/* PVCS Version: 1.10                                                   */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author     Purposes                                     */
/* 18-Jun-2003  Vicky      - (SOS#11842)                                */
/*                         Use left outer join so that those orders     */
/*                         which is not go through pack module will be  */
/*                         able to retrieve.                            */
/* 06-NOV-2003  Shong      - Remove duplicate lines for 1 load.         */
/* 19-Feb-2004  WANYT      - (SOS#20100)                                */
/*                         Additional filter to retrieve record within  */
/*                         parameters facility start & fcility end.     */
/* 03-Dec-2004  June       - (SOS#30046) - Add QtyPicked.               */
/* 03-Aug-2005  YokeBeen   - (SOS#38255) - (YokeBeen01).                */
/*                         - Enlarged the size from NVARCHAR(45)-char(100). */
/*                         - Changed to extract data for -              */
/*                         1. ShipToCity - from C_Address4 to C_City    */ 
/*                         2. ShipToAddress - from C_Address1 to        */
/*                                            C_Address3 + C_Address4 + */
/*                                            C_Address2                */ 
/* 29-Nov-2005	 MaryVong	SOS42901 NIKECN - Add PickSlipNo            */
/* 06-Oct-2016	 TLTING     SET OPTION                                  */
/*                                                                      */
/* 26-Feb-2018   CSCHONG    WMS-3990 add new field (CSO1)               */
/* 03-Oct-2020   TLTING01   Performance tune                            */
/************************************************************************/

CREATE  PROC [dbo].[nsp_Nike_BOL_Summ] (
		@c_loadkey_start NVARCHAR(10),
		@c_loadkey_end NVARCHAR(10),
		@dt_shipdate_start datetime,
		@dt_shipdate_end datetime,
		@c_facility_start NVARCHAR(5),  
		@c_facility_end NVARCHAR(5)  
) 
AS
BEGIN  
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF
   
   
   
   /*CS01 Start*/
   
   DECLARE @c_loadkey NVARCHAR(20)
          ,@c_Refno   NVARCHAR(20)
   
   /*CS01 End*/
   
	-- Added By WANYT on 19 Feb 2004 - START
	-- Create table #tempbol and set some field to allow null value
   CREATE TABLE #TEMPBOL (
         ROWREF          Uniqueidentifier not NULL default NEWID(),  -- TLTING01
			Loadkey         NVARCHAR(10),
			EditDate        datetime,
			ShipQty         int,
			FreightCost     NVARCHAR(30) NULL,
			Carrierkey      NVARCHAR(15) NULL,
			ConsigneeKey    NVARCHAR(15) NULL,   
			C_Address       NVARCHAR(100) NULL,   		-- (YokeBeen01) 
			C_City          NVARCHAR(45)NULL,   				-- (YokeBeen01)
			PodReceivedDate datetime NULL,
			PODDate01       datetime NULL,
			PODDef07        NVARCHAR(30) NULL,
			Adddate         datetime,
			PickSlipNo      NVARCHAR(10) NULL	-- SOS42901  --CS01
			,DC             NVARCHAR(50) )                   --CS01

   CREATE INDEX IX_TEMPBOL_Loadkey on #TEMPBOL (Loadkey , DC )  -- TLTING01
	-- Added By WANYT on 19 Feb @004 - END

   -- Modified By SHONG on 06-NOV-2003 
   -- Modified BY WANYT on 19 Feb 2004 
   -- TLTING01
	INSERT INTO #tempbol   (    Loadkey, EditDate, ShipQty, FreightCost    
                        , Carrierkey, ConsigneeKey, C_Address, C_City
                        , PodReceivedDate, PODDate01, PODDef07, Adddate        
                        , PickSlipNo, DC   )

SELECT LOADPLAN.Loadkey,
          MBOL.Editdate,
          shipQty = SUM(PD.qty),                                 --CS01
          FreightCost = '',
          CASE WHEN ( ISNULL(TRIM(LOADPLAN.Carrierkey), '') = ''  ) AND
                     ORDERS.Facility IN ('NSH01', 'NSH03', 'NGZ01', 'NGZ03') THEN 'DUMMY'
               ELSE LOADPLAN.Carrierkey
          END as Carrierkey,
          ConsigneeKey = '',   
          C_Address = '',   		-- (YokeBeen01) 
          C_City = '',   			-- (YokeBeen01) 
          PodReceivedDate = GetDate(),
          PODDate01 = GetDate(),
          PODDef07 = '',
          LOADPLAN.Adddate,
			 PICKHEADER.PickHeaderKey,	-- SOS42901
			 case when isnull(C.Code,'') <> '' THEN C.Code ELSE L.PickZone END AS DC    --CS01
    FROM dbo.MBOL MBOL (NOLOCK)
        JOIN dbo.MBOLDETAIL MD (NOLOCK) ON (MBOL.Mbolkey = MD.Mbolkey )
        JOIN dbo.ORDERS Orders (NOLOCK) ON (MD.Orderkey = ORDERS.Orderkey  )
        JOIN dbo.LOADPLAN (NOLOCK) ON (ORDERS.Loadkey = LOADPLAN.Loadkey )
        JOIN POD pod (NOLOCK) ON (LOADPLAN.Loadkey = POD.Loadkey 
                                   and POD.Orderkey = Orders.Orderkey ) 
     -- SOS42901
			JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LOADPLAN.LoadKey)
			--CS01 start
			LEFT JOIN PICKDETAIL PD (NOLOCK) ON PD.orderkey = ORDERS.OrderKey  
			LEFT JOIN LOC L WITH (NOLOCK) ON L.loc=pd.Loc
			LEFT JOIN CODELKUP C WITH (NOLOCK) ON C.listname = N'ALLSorting' AND
			C.Storerkey=ORDERS.StorerKey AND C.code2=L.PickZone
			--CS01 End
   WHERE ( ORDERS.Status = '9' ) and
         ( LOADPLAN.Loadkey BETWEEN @c_loadkey_start AND @c_loadkey_end ) and
         ( MBOL.Editdate BETWEEN @dt_shipdate_start AND @dt_shipdate_end ) and
         ( LOADPLAN.Facility BETWEEN @c_facility_start AND @c_facility_end )
   GROUP BY LOADPLAN.Loadkey,
         MBOL.Editdate,
         CASE WHEN ( ISNULL(TRIM(LOADPLAN.Carrierkey), '') = ''  ) AND
                     ORDERS.Facility IN ('NSH01', 'NSH03', 'NGZ01', 'NGZ03') THEN 'DUMMY'
               ELSE LOADPLAN.Carrierkey
         END,
         LOADPLAN.Adddate,
			PICKHEADER.PickHeaderKey	-- SOS42901   
			,case when isnull(C.Code,'') <> '' THEN C.Code ELSE L.PickZone END     --CS01


   -- Added By SHONG on 06-NOV-2003 (begin)
   UPDATE #TEMPBOL
      SET FreightCost = POD.PODDef06,
          PODDef07    = POD.PODDef07,
          PodReceivedDate = POD.PodReceivedDate,
          PODDate01 = POD.actualdeliverydate
   FROM POD (NOLOCK)
   WHERE #TEMPBOL.LoadKey = POD.LoadKey

   UPDATE #TEMPBOL
      SET ConsigneeKey = ORDERS.ConsigneeKey,
          -- (YokeBeen01) - Start
          C_City = ORDERS.C_City,   
          C_Address = TRIM(ORDERS.C_Address3) + ' ' + TRIM(ORDERS.C_Address4) + ' ' + 
                   TRIM(ORDERS.C_Address2) 
          -- (YokeBeen01) - End
   FROM  ORDERS (NOLOCK)
   WHERE #TEMPBOL.LoadKey = ORDERS.LoadKey
   -- Added By SHONG on 06-NOV-2003 (end)
   
   /*CS01 Start*/
     CREATE TABLE #TEMPBOLQty (
         ROWREF          uniqueidentifier not NULL PRimary key default NEWID(),  -- TLTING01
			Loadkey         NVARCHAR(10) NULL,
			PickSlipNo      NVARCHAR(10) NULL,
			DC              NVARCHAR(20) NULL,
			Qty             INT)
			
			INSERT INTO #TEMPBOLQty
			(
				Loadkey,
				PickSlipNo,
				DC,
				Qty
			)
			SELECT LP.LoadKey,PICKHEADER.PickHeaderKey,c.Code,SUM(qty) QTY 
			FROM  dbo.Loadplan LP (NOLOCK)
         JOIN  dbo.orders ord (NOLOCK) ON ord.Loadkey=LP.Loadkey 
         JOIN  dbo.PICKDETAIL pd (NOLOCK)  ON pd.OrderKey=Ord.OrderKey   
         JOIN  dbo.MBOLDETAIL MD (NOLOCK) ON (MD.Orderkey = ord.Orderkey )
			JOIN  dbo.MBOL MBOL (NOLOCK) ON (MBOL.Mbolkey = MD.Mbolkey )
			JOIN  dbo.loc (nolock) l ON pd.Loc=l.Loc
			JOIN  dbo.CODELKUP (nolock) c ON c.LISTNAME=N'allsorting' 
			      AND l.PickZone=c.code2 AND pd.Storerkey=c.Storerkey
			JOIN PICKHEADER (NOLOCK) ON (PICKHEADER.ExternOrderKey = LP.LoadKey)
			WHERE  ( ORD.Status = '9' ) and 
          ( LP.Loadkey BETWEEN @c_loadkey_start AND @c_loadkey_end )  and
          ( MBOL.EditDate BETWEEN @dt_shipdate_start AND @dt_shipdate_end ) and
          ( ord.Facility BETWEEN @c_facility_start AND @c_facility_end )	
			 GROUP BY c.code,LP.LoadKey ,PICKHEADER.PickHeaderKey
			
			UPDATE #TEMPBOL
			SET ShipQty = TBQ.Qty
			FROM #TEMPBOLQty TBQ
			WHERE #TEMPBOL.loadkey = TBQ.Loadkey
			AND #TEMPBOL.PickSlipNo = TBQ.PickSlipNo
			AND #TEMPBOL.DC = TBQ.DC
			
 /*CS01 End*/			
   
    CREATE TABLE #TEMPPACK (
      ROWREF          uniqueidentifier not NULL PRimary key default NEWID(), -- TLTING01
      Cartonno int,
      Loadkey NVARCHAR(10),
      Orderkey NVARCHAR(10),
      labelno  NVARCHAR(20),    --CS01
      DC       NVARCHAR(20)     --CS01
      )

    -- Modified BY WANYT on 19 Feb 2004 
    INSERT INTO #TEMPPACK (Cartonno, Loadkey, Orderkey,labelno,DC)      --CS01
    SELECT DISTINCT PACKDETAIL.Cartonno ,
                    PACKHEADER.Loadkey,
                    PACKHEADER.Orderkey
                    ,PACKDETAIL.labelno                               --CS01
                    ,PACKDETAIL.RefNo                                 --CS01
    FROM PACKHEADER (NOLOCK), PACKDETAIL (NOLOCK), LOADPLAN (NOLOCK)
    WHERE PACKHEADER.Pickslipno = PACKDETAIL.Pickslipno
      AND PACKHEADER.Loadkey = LOADPLAN.Loadkey 
      AND PACKHEADER.Loadkey between @c_loadkey_start and @c_loadkey_end
      AND LOADPLAN.Facility between @c_facility_start and @c_facility_end 
      And Exists ( Select 1 FROM #TEMPBOL WHERE #TEMPBOL.Loadkey  = LOADPLAN.Loadkey ) --tlting01

   Create table #TEMPSUMCTN (
     ROWREF          uniqueidentifier not NULL PRimary key default NEWID(),
     ShipCtn int,
     Loadkey NVARCHAR(10),
     DC      NVARCHAR(20)                    --(CS01)
      )

   INSERT INTO #TEMPSUMCTN (ShipCtn, Loadkey,DC )
   SELECT ShipCtn = count(#TEMPPACK.labelno),--count(#TEMPPACK.cartonno),      --CS01
          Loadkey,
          DC
   FROM #TEMPPACK
   GROUP BY Loadkey,DC

-- Modified by Vicky 18 June 2003 
   SELECT #TEMPBOL.Loadkey, PODDef07, Carrierkey, ConsigneeKey, C_City, C_Address, Editdate, #TEMPSUMCTN.ShipCtn,
          FreightCost, PODDate01,ShipQty, PodReceivedDate, Adddate, PickSlipNo,#TEMPBOL.DC -- SOS42901   --CS01
   FROM #TEMPBOL--, #TEMPSUMCTN
   LEFT OUTER JOIN #TEMPSUMCTN ON (#TEMPBOL.Loadkey = #TEMPSUMCTN.Loadkey) AND  #TEMPBOL.DC = #TEMPSUMCTN.DC


  DROP TABLE #TEMPBOL
  DROP TABLE #TEMPPACK    
  DROP TABLE #TEMPSUMCTN
END

GO