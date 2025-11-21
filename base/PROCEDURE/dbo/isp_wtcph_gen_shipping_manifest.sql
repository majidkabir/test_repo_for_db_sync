SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--
-- Definition for stored procedure isp_WTCPH_Gen_Shipping_Manifest : 
--

/**************************************************
* ALTER  Temporary Table for generating ff reports; 
*           Shipping Manifest - Details
*           Shipping Manifest - Summary
*           Tote Summary by Store
* last modified: 061201 - additional columns been inserted LOADDATE, VEHICLENO
**************************************************/
CREATE PROC [dbo].[isp_WTCPH_Gen_Shipping_Manifest]
--  @c_loaddate1 NVARCHAR(10)
-- ,@c_LoadDate2 NVARCHAR(10)
  @c_Dummy_LoadKey  NVARCHAR(15)
 ,@c_scandate1 NVARCHAR(10)
 ,@c_scanDate2 NVARCHAR(10)
 ,@c_ScanBatch_From NVARCHAR(16)
 ,@c_ScanBatch_TO   NVARCHAR(16)
AS
BEGIN
 
   	SET NOCOUNT ON
   	SET ANSI_WARNINGS OFF
   	SET QUOTED_IDENTIFIER OFF
   	SET ANSI_NULLS OFF

   DECLARE @b_debug int
   SET @b_debug = 1

/****

  	exec isp_WTCPH_Gen_Shipping_Manifest   '0000355752'         -- loading start 
 	                                      ,'2007-01-05'         -- loading end (despatched date)
					      ,'2007-01-10'         -- cycle starts
				              ,'2007-01-08 14:10'   -- batch start
					      ,'2007-01-10 20:00'   -- batch end
   	DECLARE  @c_loaddate1 NVARCHAR(10)
   	DECLARE  @c_LoadDate2 NVARCHAR(10)
    	DECLARE  @c_scandate1 NVARCHAR(10)
   	DECLARE  @c_scanDate2 NVARCHAR(10)
    	DECLARE  @c_ScanBatch_From NVARCHAR(16)
   	DECLARE  @c_ScanBatch_TO   NVARCHAR(16)
    	DECLARE  @c_DmyLdKey  NVARCHAR(15)

    	select @c_DmyLdKey  = @c_Dummy_LoadKey
 	select @c_loaddate1  = '2006-05-06'
 	select @c_loaddate2  = '2006-05-07'
 	select @c_scandate1  = '2006-05-05'
 	select @c_scandate2  = '2006-05-07'
 	select @c_ScanBatch_From = '2006-05-05 06:00'
 	select @c_ScanBatch_To   = '2006-05-07 06:00'

--*****/


-------------------------------------------------------------------------------------------------- 0
	if exists (SELECT * FROM IDSPH.dbo.SYSOBJECTS WHERE
                                             NAME = 'TmpFnalWTC_DRLdParam' AND  type = 'U')
	   DROP table [IDSPH].[dbo].[TmpFnalWTC_DRLdParam]

        TRUNCATE TABLE TmpFnalWTC_DR  
        TRUNCATE TABLE TmpFnalWTC_DRSum  

 	select 
	   LP.userdefine09  as DumLdNo
        ,[LoadDate] = convert( NVARCHAR(10), max(lp.adddate), 121)
 	,@c_scandate1      as ScanDate1
 	,@c_scanDate2      as ScanDate2
 	,@c_ScanBatch_From as ScanBatchFr
 	,@c_ScanBatch_TO   as ScanBatchTo	
	,[weight] = sum(weight)
        ,[NumOfStores]=count(lp.loadkey)
        ,[AddDate]  = max(lp.adddate)
	into TmpFnalWTC_DRLdParam
	from v_loadplan     lp (nolock)  where 
	       lp.facility = 'WTN' 
           and LP.userdefine09 = @c_Dummy_LoadKey 
--         and lp.userdefine09 is not null 
--         and left(lp.userdefine09,1) <> ' '
--	   and  convert(char(10) , lp.adddate, 121)  between  @c_loaddate1  
--           and @c_loaddate2 
	group by LP.userdefine09  


   IF @b_debug = 1
   BEGIN      
      SELECT '-- 0--'
      SELECT * FROM TmpFnalWTC_DRLdParam
   END
 
   DECLARE  @c_LoadDate2 NVARCHAR(10)
--------------------------------------------------------------------------------------------------------- A

	if exists (SELECT * FROM DTSITF.dbo.SYSOBJECTS WHERE NAME = 'Tmp_WTCPcked01' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[Tmp_WTCPcked01]
 	select 
	   LP.userdefine09  as DumLdNo
	,  LP.userdefine10  as DrNo
	,  od.loadkey       as GatePassNo
	,  OH.consigneekey 
	,  [Type]=  case when oh.type = 'S'  THEN 'S'
                  when oh.type = 'C'
                       then (select distinct left(potype,3) from v_po po (nolock) where po.storerkey = 'WATSONS' and po.externpokey = od.externpokey )
             end
	,  od.sku 
        ,  sk.price
	,  sk.descr  
        ,  [OrdQty]    = od.originalqty 
	,  [caseid]    = upper(pd.caseid)
	,  [PickDtlQty]= sum(pd.qty)
	,  [pickstat]= pd.status
	,  [ShpPcsQty]=000000
	,  [ShpCseQty]=000000
	,  [DeliveryDate] = convert( NVARCHAR(10) , LDS.adddate , 121)  -- @c_LoadDate2
	into  DTSITF..Tmp_WTCPcked01
	from v_pickdetail PD (nolock) 
	  inner join v_orderdetail  od (nolocK) on pd.orderkey + pd.sku + pd.orderlinenumber =  od.orderkey + od.sku + od.orderlinenumber
	  inner join v_orders       OH (NOLOCK) on pd.orderkey = oh.orderkey 
	  inner join v_loadplan     lp (nolock) on od.loadkey  = lp.loadkey
	  inner join v_sku          sk (nolock) on pd.storerkey + pd.sku = sk.storerkey + sk.sku 
	  inner join TmpFnalWTC_DRLdParam  Lds  on lp.userdefine09 = LDS.DumLdNo
	where pd.storerkey = 'watsons'  
	group by LP.userdefine09  
	,  LP.userdefine10   
	,  OH.consigneekey 
	,  od.sku 
	,  sk.descr  
	,  pd.caseid
	,  pd.uom
	,  pd.status
	,  oh.type
	,  od.externpokey
	,  od.loadkey       
        ,  sk.price
	,  od.originalqty 
        ,convert( NVARCHAR(10) , LDS.adddate , 121)  
-----   SELECT * FROM  DTSITF..Tmp_WTCPcked01

   	select @c_LoadDate2 = max(DeliveryDate)
        from DTSITF..Tmp_WTCPcked01 (nolock)

   IF @b_debug = 1
   BEGIN
      SELECT '-- A--'      
      SELECT * FROM DTSITF..Tmp_WTCPcked01   
      SELECT @c_LoadDate2 '@c_LoadDate2'
   END

	if exists (SELECT * FROM DTSITF.dbo.SYSOBJECTS WHERE NAME = 'TmpOrdD01' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[TmpOrdD01]
	select 
	   [DeliveryDate] = convert( NVARCHAR(10) , LDS.adddate , 121)  
	,  LP.userdefine09  as DumLdNo
	,  LP.userdefine10  as DrNo
	,  od.loadkey       as GatePassNo
	,  OH.consigneekey 
	,  [Type]=  case when oh.type = 'S'  THEN 'S'
                  when oh.type = 'C'
                       then (select distinct left(potype,3) from v_po po (nolock) where po.storerkey = 'WATSONS' and po.externpokey = od.externpokey )
             end
 	,  od.sku 
        ,  sk.price
	,  sk.descr  
        ,  [OrdQty]    = sum(od.originalqty) 
        ,  [AllocQty]    = sum(od.qtyallocated+od.qtypicked+od.shippedqty) 
        ,  [ShipQty]=   0000000
	into  DTSITF..TmpOrdD01
	from  v_orderdetail  od (nolocK) 
	  inner join v_orders       OH (NOLOCK) on od.orderkey = oh.orderkey 
	  inner join v_loadplan     lp (nolock) on od.loadkey  = lp.loadkey
	  inner join v_sku          sk (nolock) on od.storerkey + od.sku = sk.storerkey + sk.sku 
	  inner join TmpFnalWTC_DRLdParam  LDS  on lp.userdefine09 = LDS.DumLdNo
	where od.storerkey = 'watsons'  and (od.qtyallocated+od.qtypicked+od.shippedqty)> 0
	group by 
           LP.userdefine09  
	,  LP.userdefine10   
 	,  od.loadkey       
	,  OH.consigneekey 
	,  od.sku 
	,   oh.type 
        ,  od.externpokey
        ,  sk.price
	,  sk.descr  
        ,  convert( NVARCHAR(10) , LDS.adddate , 121)  

   IF @b_debug = 1
   BEGIN
      SELECT '-- A--'
      SELECT * FROM DTSITF..TmpOrdD01   
   END
--------------  
-- @Ls 060909 
--------------

	if exists (SELECT * FROM IDSPH.dbo.SYSOBJECTS WHERE NAME = 'TmpFnalWTC_DR_by_ordType' AND  type = 'U')
	   DROP table [IDSPH].[dbo].[TmpFnalWTC_DR_by_ordType]

 	select OD.*
        , [RefNo1] = '               '
        , [RefNo2] = '               '
        , [RefNo3] = '               '
        , [RefNo4] = '               '
        , mh.vessel as MBOLtruckno
        , mh.drivername 
        , [MBOLShpDte] = convert( NVARCHAR(16) , mh.editdate , 121)
        , [RunDate]    = convert( NVARCHAR(16), getdate() , 121)
        ,  [TruckNo]= '          '
        ,  [LdDate] = '                '
        ,  [LdedBy] = '          '
	into   TmpFnalWTC_DR_by_OrdType 
	from DTSITF..Tmp_WTCPcked01 OD (nolock) 
                left outer join loadplan LP (nolock) on od.GatePassNo = lp.loadkey  
                left outer join mbol     MH (nolock) on LP.mbolkey = mh.mbolkey 
	where left(OD.caseid,1) in ('C','K','T','V')

   IF @b_debug = 1
   BEGIN
      SELECT '-- A--'
      SELECT * FROM TmpFnalWTC_DR_by_ordType
   END
--------------
-- @Ls 060909 
-------------- 


-------------------------------------------------------------------------------------------------------- B
----  3   get data from actual item pass thru  PPP-PPA
	if exists (SELECT * FROM DTSITF.dbo.SYSOBJECTS WHERE NAME = 'TmpPPA_DR' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[TmpPPA_DR]
	select  
	  SP.consigneekey 
	, SP.type 
	, SP.caseid
        , SP.Refno1
        , SP.Refno2
        , SP.Refno3
        , SP.Refno4
	, SP.sku 
	, [shipQty] = sum(SP.countqty_b)
        , [TruckNo] =  '         ' 
--        , [TruckNo] = case when ST.status = '9'  then  ST.vehicle  
--                           when ST.status <> '9' then '         ' 
--                      end
        , [LdDate]  = '          '
--        , [LdDate]  = case when ST.status = '9' then  convert(char(10), ST.editdate , 121) when ST.status <> '9' then '                ' end
        , [LdedBy]  =  '         ' 
--        , [LdedBy]  = case when ST.status = '9' then  ST.editwho  when ST.status <> '9' then '         ' end
	into DTSITF..TmpPPA_DR
	from dbo.v_rdtcsaudit SP (nolock) 
  inner join dbo.v_rdtcsaudit_load ST (nolock)  
                               on SP.consigneekey = ST.consigneekey and 
                                  SP.caseid  = ST.caseid   and 
                                  SP.groupid = ST.groupid 
	where SP.status >= '5' and left(SP.caseid,1) in ('C','K','T','V')                                    -- thur             -- sun
	   AND convert(char(10), SP.adddate , 121) 
	      between @c_ScanDate1 and @c_ScanDate2
	group by 
	  SP.consigneekey 
	, SP.type 
	, SP.caseid
        , SP.Refno1
        , SP.Refno2
        , SP.Refno3
        , SP.Refno4
	, SP.sku 
--        , ST.status 
--        , ST.vehicle
--        , ST.editdate   --- causing multiple records for multiple scanned consigneekey+caseid+sku
--        , ST.EDITWHO 

   IF @b_debug = 1
   BEGIN
      SELECT '-- B--'
      SELECT * FROM DTSITF..TmpPPA_DR
   END
   
------------------------------------------------------------------------------------------------- C
-- XDOCK AND STORAGE
	if exists (SELECT * FROM DTSITF.dbo.SYSOBJECTS WHERE NAME = 'Tmp_WTCOut01' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[Tmp_WTCOut01]
	select 
	   DeliveryDate
 	,  consigneekey 
	,  DrNo
        ,  GatePassNo
        ,  [Rep01Code] = case when left(caseid, 1) = 'C' then 'D '
			      when left(caseid, 1) = 'T' then 'E1' 
			      when left(caseid, 1) = 'K' then 'E2' 
			      when left(caseid, 1) = 'V' then 'E3' 
			 end
        ,  [Rep01Desc] = case when left(caseid, 1) = 'C' then 'Full Case                '
			      when left(caseid, 1) = 'T' then 'Tote Boxes               ' 
			      when left(caseid, 1) = 'K' then 'Carton Boxes             ' 
			      when left(caseid, 1) = 'V' then 'Carton Boxes             ' 
			 end
	,  sku 
	,  descr  
        ,  price
	,  caseid
        , [Refno1] = '                     '
        , [Refno2] = '                     '
        , [Refno3] = '                     '
        , [Refno4] = '                     '
        ,  [Rep02Code] = case when left(caseid, 1) = 'C' then '  '
			      when left(caseid, 1) = 'T' then 'Tote# '    + dbo.fnc_LTRIM(dbo.fnc_RTRIM(caseid)) 
			      when left(caseid, 1) = 'K' then 'Carton# '  + dbo.fnc_LTRIM(dbo.fnc_RTRIM(caseid)) 
			      when left(caseid, 1) = 'V' then 'Carton# '  + dbo.fnc_LTRIM(dbo.fnc_RTRIM(caseid))  
			 end
        ,  [Ordqty]   = sum(ordqty)
	,  [PickDtlQty]= sum(PickDtlQty)
	,  [ShpPcsQty]=000000
	,  [ShpCseQty]=000000
        ,  [TruckNo]= '          '
        ,  [LdDate] = '                '
        ,  [LdedBy] = '          '
	into DTSITF..Tmp_WTCOut01
	from DTSITF..Tmp_WTCPcked01 
	where type <> 'SA'  and left(caseid, 1) in ('C','K','T','V')
	group by 
	   DeliveryDate
	,  consigneekey 
	,  DrNo
	,  sku 
	,  descr  
	,  caseid
        ,  gatepassno
        ,  price
        
   IF @b_debug = 1
   BEGIN
      SELECT '-- C--'
      SELECT * FROM DTSITF..Tmp_WTCOut01        
   END
-------------------------------------------------------------------------------------------------- D
	update DTSITF..Tmp_WTCOut01
	   set ShpPcsQty = ppa.ShipQty 
	        , ShpCseQty = 1
                , TruckNo = PPA.TruckNo
                , LdDate = PPA.LdDate
                , LdedBy = PPA.LdedBy
	      from DTSITF..Tmp_WTCOut01 Shp 
	inner join DTSITF..TmpPPA_DR  PPA on Shp.Consigneekey = ppa.consigneekey 
                                     and shp.caseid = ppa.caseid
                                     AND shp.sku = ppa.sku  
	where left(Shp.caseid,1) = 'C'

 	update DTSITF..Tmp_WTCOut01 
	   set ShpPcsQty = ppa.ShipQty 
        	, Refno1 = isnull( PPA.Refno1, ' ' )
        	, Refno2 = isnull( PPA.Refno2,' ' )
        	, Refno3 = isnull( PPA.Refno3,' ' )
        	, Refno4 = isnull( PPA.Refno4, ' ' )
                , TruckNo = PPA.TruckNo
                , LdDate  = PPA.LdDate
                , LdedBy  = PPA.LdedBy
	      from DTSITF..Tmp_WTCOut01  Shp 
	inner join DTSITF..TmpPPA_DR  PPA on Shp.Consigneekey = ppa.consigneekey 
                                     and shp.caseid = ppa.caseid
                                     AND shp.sku = ppa.sku 
	where left(Shp.caseid,1) in ('K','T','V')

   IF @b_debug = 1
   BEGIN
      SELECT '-- D-- After Update'
      SELECT * FROM DTSITF..Tmp_WTCOut01
   END    
      
--------------  
-- @Ls 060909 
--------------
	update TmpFnalWTC_DR_by_OrdType 
	   set ShpPcsQty = ppa.ShipQty 
        	, Refno1 = isnull( PPA.Refno1, ' ' )
        	, Refno2 = isnull( PPA.Refno2,' ' )
        	, Refno3 = isnull( PPA.Refno3,' ' )
        	, Refno4 = isnull( PPA.Refno4, ' ' )
                , TruckNo = PPA.TruckNo
                , LdDate = PPA.LdDate
                , LdedBy = PPA.LdedBy
	      from TmpFnalWTC_DR_by_OrdType  Shp 
	inner join DTSITF..TmpPPA_DR  PPA on Shp.Consigneekey = ppa.consigneekey 
                                     and shp.caseid = ppa.caseid
                                     AND shp.sku = ppa.sku  
	where left(Shp.caseid,1) in ('K','T','V')
	
   IF @b_debug = 1
   BEGIN
      SELECT '-- D-- After Update'
      SELECT * FROM TmpFnalWTC_DR_by_OrdType
   END      	
--------------  
-- @Ls 060909 
--------------

 
---------------------------------------------------------------------------------------------------------- E
----  STOREADD  DATA 
	if exists (SELECT * FROM DTSITF.dbo.SYSOBJECTS WHERE NAME = 'Tmp_WTCOut02' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[Tmp_WTCOut02]
	select  
	 [DeliveryDate]=@c_LoadDate2
	, rdt.consigneekey 
	, [drno]       = (select min(drno)        FROM  DTSITF..Tmp_WTCOut01 (nolock) where consigneekey = rdt.consigneekey)
	, [gatepassno] = (select min(gatepassno)  FROM  DTSITF..Tmp_WTCOut01 (nolock) where consigneekey = rdt.consigneekey)
        ,  [Rep01Code] = case when left(rdt.caseid,1)  = 'S' then 'A '
			      when left(rdt.caseid, 1) = 'B' then 'B ' 
			      when left(rdt.caseid, 1) = 'R' then 'C ' 
 			 end
        ,  [Rep01Desc] = case when left(rdt.caseid, 1) = 'S' then 'Store Addressed'
			      when left(rdt.caseid, 1) = 'B' then 'BST Boxes' 
			      when left(rdt.caseid, 1) = 'R' then 'Consignor Boxes' 
			 end
	, sku 
        , [Descr]      = rdt.caseid
        , [Price]=     000.00
	, [caseid]     = '         '
        , [Refno1] = '                     '
        , [Refno2] = '                     '
        , [Refno3] = '                     '
        , [Refno4] = '                     '
        , [Rep02Code]  = '         '
        , [Ordqty]     =  00000
        , [PickDtlqty] = 00000
        , [ShpPcsQty]  = 00000
	, [ShpCseQty]  = rdt.countqty_b
        , [TruckNo] = case when ST.status = '9'  then  ST.vehicle  
                           when ST.status <> '9' then '         ' 
                      end
        , [LdDate]  = case when ST.status = '9' then  convert(char(16), ST.editdate , 121) when ST.status <> '9' then '                ' end
        , [LdedBy]  = case when ST.status = '9' then  ST.editwho  when ST.status <> '9' then '         ' end
	into DTSITF..Tmp_WTCOut02
	from v_rdtcsaudit     rdt (nolock)  
  inner join v_rdtcsaudit_load ST (nolock) 
                               on rdt.consigneekey = ST.consigneekey and 
                                  rdt.caseid = ST.caseid   and 
                                  rdt.groupid = ST.groupid 
	where rdt.status >= '5' and left(rdt.caseid,1) NOT in ('C','K','T','V')                                    -- thur             -- sun
	   AND convert(char(13), rdt.adddate , 121) 
	      between @c_ScanBatch_From and @c_ScanBatch_To
	      
   IF @b_debug = 1
   BEGIN
      SELECT '-- E--'
      SELECT * FROM DTSITF..Tmp_WTCOut02  	      
   END
----------------------------------------------------------------------------------------------------------------- F
	if exists (SELECT * FROM IDSPH.dbo.SYSOBJECTS WHERE NAME = 'TmpFnalWTC_DR01' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[TmpFnalWTC_DR01]

        SELECT * 
        into DTSITF..TmpFnalWTC_DR01
        FROM  DTSITF..Tmp_WTCOut01
 
        insert into DTSITF..TmpFnalWTC_DR01
        SELECT * FROM DTSITF..Tmp_WTCOut02

   IF @b_debug = 1
   BEGIN
      SELECT '-- F--'
      SELECT * FROM DTSITF..TmpFnalWTC_DR01
   END

	if exists (SELECT * FROM IDSPH.dbo.SYSOBJECTS WHERE NAME = 'TmpFnalWTC_DR' AND  type = 'U')
              begin
		  delete from TmpFnalWTC_DR
		  insert into TmpFnalWTC_DR select * from DTSITF..TmpFnalWTC_DR01
              end                 
        else 
	      begin
		  select *  into TmpFnalWTC_DR from DTSITF..TmpFnalWTC_DR01
              end
        delete from TmpFnalWTC_DR where left(caseid,1) = 'C' and ShpPcsQty = 0
        drop table DTSITF..TmpFnalWTC_DR01
--	SELECT * FROM  TmpFnalWTC_DR
         
   IF @b_debug = 1
   BEGIN
      SELECT '-- F--'
      SELECT * FROM TmpFnalWTC_DR
   END

-------------------------------------------------------------------------------------------------------- G
 	drop table DTSITF..Tmp_WTCOut01b
        select 
	   DeliveryDate
 	,  consigneekey 
	,  DrNo
        ,  GatePassNo
	,  sku 
        ,  [PickDtlQty] = sum(PickDtlQty)
        ,  [ShpPcsQty]  = sum(ShpPcsQty)
 	into DTSITF..Tmp_WTCOut01b
 	from  DTSITF..Tmp_WTCOut01
	group by
	   DeliveryDate
	,  consigneekey 
	,  DrNo
        ,  GatePassNo
	,  sku 

   IF @b_debug = 1
   BEGIN
      SELECT '-- G--'
      SELECT * FROM DTSITF..Tmp_WTCOut01b
   END
   
	if exists (SELECT * FROM DTSITF.dbo.SYSOBJECTS WHERE NAME = 'TmpFnalWTC_DRSum00' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[TmpFnalWTC_DRSum00]
 	select 
            ord.deliverydate
	,   ord.DumLdNo
	,   ord.DrNo
	,   ord.GatePassNo
	,   ord.consigneekey 
        ,  [Rep01Code] = case when ord.type = 'SA' then 'A '
			      when ord.type = 'S'  then 'B '
			      when ord.type = 'C'  then 'B '
			 end
        ,  [Rep01Desc] = case when ord.type = 'SA' then 'Store Addressed '
			      when ord.type = 'S' then 'OTHERS' 
			      when ord.type = 'C' then 'OTHERS' 
			 end
 	,   ord.sku 
        ,   ord.price
	,   ord.descr  
        ,   [OrdQty]=SUM(ord.OrdQty)
        ,   [AllocQty]=SUM(ord.AllocQty)
        ,   [ShipQty] = 000000 --sum( isnull( Scnd.PickDtlQty , 0) )
	into DTSITF..TmpFnalWTC_DRSum00
        from DTSITF..TmpOrdD01 ord  (nolock) 
             left outer join DTSITF..Tmp_WTCOut01B Scnd on
 	     ord.consigneekey = Scnd.consigneekey 
	and  ord.DrNo         = Scnd.DrNo
        and  ord.gatepassno   = Scnd.gatepassno
	and  ord.sku          = Scnd.sku 
        and  ord.deliverydate = Scnd.Deliverydate
        group by 
            ord.deliverydate
	,   ord.DumLdNo
	,   ord.DrNo
	,   ord.GatePassNo
	,   ord.consigneekey 
 	,   ord.sku 
        ,   ord.price
	,   ord.descr  
--        ,   ord.OrdQty
--        ,   ord.AllocQty
	,   ord.type 

   IF @b_debug = 1
   BEGIN
      SELECT '-- G--'
      SELECT * FROM DTSITF..TmpFnalWTC_DRSum00
   END

	if exists (SELECT * FROM DTSITF.dbo.SYSOBJECTS WHERE NAME = 'TmpFnalWTC_DRSum01' AND  type = 'U')
	   DROP table [DTSITF].[dbo].[TmpFnalWTC_DRSum01]
 	select 
             deliverydate
	,    DumLdNo
	,    DrNo
	,    GatePassNo
	,    consigneekey 
        ,    Rep01Code
        ,    Rep01Desc
 	,    sku 
        ,    price
	,    descr  
        ,   [OrdQty]=SUM(OrdQty)
        ,   [AllocQty]=SUM(AllocQty)
        ,   [ShipQty] = 000000 --sum( isnull( Scnd.PickDtlQty , 0) )
	into DTSITF..TmpFnalWTC_DRSum01
        from DTSITF..TmpFnalWTC_DRSum00 (nolock) 
        group by 
             deliverydate
	,    DumLdNo
	,    DrNo
	,    GatePassNo
	,    consigneekey 
        ,    Rep01Code
        ,    Rep01Desc
 	,    sku 
        ,    price
	,    descr  

   IF @b_debug = 1
   BEGIN
      SELECT '-- G--'
      SELECT * FROM DTSITF..TmpFnalWTC_DRSum01
   END

	update  DTSITF..TmpFnalWTC_DRSum01 set
       ShipQty = Tmp_WTCOut01B.ShpPcsQty   --PickDtlQty 
	from DTSITF..TmpFnalWTC_DRSum01  Src inner join DTSITF..Tmp_WTCOut01B Tmp_WTCOut01B on
	    Src.DeliveryDate = Tmp_WTCOut01B.DeliveryDate
	and Src.consigneekey = Tmp_WTCOut01B.consigneekey 
	and Src.DrNo = Tmp_WTCOut01B.DrNo
        and Src.GatePassNo = Tmp_WTCOut01B.GatePassNo
	and Src.sku = Tmp_WTCOut01B.sku 
        where src.Rep01Code  <> 'A'

   IF @b_debug = 1
   BEGIN
      SELECT '-- G-- After Update'
      SELECT * FROM DTSITF..TmpFnalWTC_DRSum01
   END

	if  exists (SELECT * FROM IDSPH.dbo.SYSOBJECTS WHERE NAME = 'TmpFnalWTC_DRSum' AND  type = 'U')
           begin
 	      delete from TmpFnalWTC_DRSum
              insert into TmpFnalWTC_DRSum select * from DTSITF..TmpFnalWTC_DRSum01
           end
	else
           begin
 	      select * into TmpFnalWTC_DRSum  from  DTSITF..TmpFnalWTC_DRSum01 
           end
 	drop table DTSITF..TmpFnalWTC_DRSum01 

        -- TO ENSURE TABLE WILL BE DROPPED UPON COMPLETING THE SCRIPT CAUSING THE ERROR                               
 	drop table DTSITF..TmpFnalWTC_DRSum00 
                               
   IF @b_debug = 1
   BEGIN
      SELECT '-- G--'
      SELECT * FROM TmpFnalWTC_DRSum
   END
  
/****
*	select * FROM  DTSITF..TmpFnal_DR
*	order by consigneekey, drno, rep01code, descr
*
*	select * FROM  TmpFnalWTC_DRSum
*	order by consigneekey, drno, rep01code, descr
* 
****/
 
END

GO