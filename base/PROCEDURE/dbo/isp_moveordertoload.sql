SET ANSI_NULLS OFF;
GO
SET QUOTED_IDENTIFIER OFF;
GO

/************************************************************************/
/* Stored Procedure: isp_MoveOrderToLoad                                */
/* Creation Date: 12-03-2012                                            */
/* Copyright: IDS                                                       */
/* Written by: YTWan                                                    */
/*                                                                      */
/* Purpose: SOS#236130: Move orders to new/other loadplan               */
/*                                                                      */
/* Called By: w_move_loadplandetail - ue_move()                         */ 
/*                                                                      */
/* Parameters:                                                          */
/*                                                                      */
/* PVCS Version: 1.0	                                                  */
/*                                                                      */
/* Version: 5.4                                                         */
/*                                                                      */
/* Data Modifications:                                                  */
/*                                                                      */
/* Updates:                                                             */
/* Date         Author    Ver.  Purposes                                */
/* 17-Feb-2017  NJOW01    1.0   WMS-987 CN Charming Charlie combine load*/
/*                              and conso pack                          */
/* 18-Aug-2017  CheeMun   1.1   WMS-987 CN Charming Charlie not update  */
/*								        packinfo weight (CM01)		     		   */
/* 28-Jan-2019  TLTING_ext 1.2  enlarge externorderkey field length      */
/************************************************************************/

CREATE PROC [dbo].[isp_MoveOrderToLoad]
      @c_LoadKey        NVARCHAR(10)
   ,  @c_LoadlineNumber NVARCHAR(5) 
   ,  @c_ToLoadKey      NVARCHAR(10) OUTPUT  
   ,  @b_success        INT         OUTPUT
   ,  @n_err            INT         OUTPUT
   ,  @c_errmsg         NVARCHAR(225)   OUTPUT    
AS
BEGIN
   SET NOCOUNT ON 
   SET ANSI_NULLS OFF 
   SET QUOTED_IDENTIFIER OFF 
   SET CONCAT_NULL_YIELDS_NULL OFF

   DECLARE @n_continue          INT
         , @n_starttcnt         INT
         , @n_createnew         INT

	 DECLARE @c_facility 		      NVARCHAR(5) 
          ,@c_toloadlinenumber  NVARCHAR(5)
	 		    ,@c_orderkey          NVARCHAR(10)
	 		    ,@c_externorderkey    NVARCHAR(50)  --tlting_ext
	 		    ,@c_consigneekey      NVARCHAR(15)
	 		    ,@c_customername      NVARCHAR(50)
	 		    ,@c_priority          NVARCHAR(10)
	 		    ,@dt_orderdate      	DATETIME   
	 		    ,@dt_deliverydate     DATETIME   
	 		    ,@c_deliveryplace     NVARCHAR(30)
	 		    ,@c_Type              NVARCHAR(10)
	 		    ,@c_Door              NVARCHAR(10)
	 		    ,@c_Stop              NVARCHAR(10)
	 		    ,@c_Route             NVARCHAR(10)
	 		    ,@n_weight           	FLOAT      
	 		    ,@n_cube              FLOAT      
	 		    ,@c_status            NVARCHAR(10)
	 		    ,@n_casecnt        	  FLOAT      
	 		    ,@n_noofordlines   	  INT        
	 		    ,@c_rdd               NVARCHAR(20)
	 		    ,@c_userdefine01      NVARCHAR(20)
	 		    ,@c_userdefine02      NVARCHAR(20)
	 		    ,@c_userdefine03      NVARCHAR(20)
	 		    ,@c_userdefine04      NVARCHAR(20)
	 		    ,@c_userdefine05      NVARCHAR(20)
	 		    ,@dt_userdefine06  	  DATETIME   
	 		    ,@dt_userdefine07  	  DATETIME   
	 		    ,@c_userdefine08      NVARCHAR(20)
	 		    ,@c_userdefine09      NVARCHAR(20)
	 		    ,@c_userdefine10      NVARCHAR(20)
          
   --NJOW01
   DECLARE @c_FromPickslipno    NVARCHAR(10)
           ,@c_ToPickslipno     NVARCHAR(10)
           ,@c_RefKeylkup       NVARCHAR(1)
           ,@c_DropID           NVARCHAR(20)
           ,@c_Sku              NVARCHAR(20)
           ,@n_Qty              INT
           ,@c_Storerkey        NVARCHAR(15)
           ,@n_LastCartonNo     INT
           ,@n_CartonNo         INT
           ,@c_LabelLine        NVARCHAR(5)
           ,@c_PrevDropID       NVARCHAR(20)
           ,@n_FromCartonno     INT
           ,@n_CtnCube          FLOAT
           ,@n_CtnWgt           FLOAT
           ,@n_CtnQty           INT

   SET @n_continue = 1
   SET @n_starttcnt= @@TRANCOUNT
   SET @n_createnew= 0

	 SET @c_facility 			    = ''  
	 SET @c_toloadlinenumber  = ''  
	 SET @c_orderkey          = ''  
	 SET @c_externorderkey    = ''  
	 SET @c_consigneekey      = ''  
	 SET @c_customername      = ''  
	 SET @c_priority          = ''  
	 SET @c_deliveryplace   	= ''  
	 SET @c_Type            	= ''  
	 SET @c_Door            	= ''  
	 SET @c_Stop            	= ''  
	 SET @c_Route           	= ''  
	 SET @n_weight            = 0.00
	 SET @n_cube              = 0.00
	 SET @c_status         	  = ''  
	 SET @n_casecnt        	  = 0.00
	 SET @n_noofordlines   	  = 0   
	 SET @c_rdd            	  = ''  
	 SET @c_userdefine01   	  = ''  
	 SET @c_userdefine02      = ''  
	 SET @c_userdefine03      = ''  
	 SET @c_userdefine04      = ''  
	 SET @c_userdefine05      = ''  
	 SET @c_userdefine08      = ''  
	 SET @c_userdefine09      = ''  
	 SET @c_userdefine10      = ''  
           
   SELECT  @c_facility = ISNULL(RTRIM(Facility),'')         
   FROM LOADPLAN WITH (NOLOCK)       
   WHERE LoadKey = @c_LoadKey  

   SELECT  @c_orderkey       = orderkey         
			   , @c_externorderkey = ISNULL(RTRIM(externorderkey),'')   
			   , @c_consigneekey   = ISNULL(RTRIM(consigneekey),'')     
			   , @c_customername   = ISNULL(RTRIM(customername),'')     
			   , @c_priority       = ISNULL(RTRIM(priority),'')         
			   , @dt_orderdate     = orderdate        
			   , @dt_deliverydate  = deliverydate     
			   , @c_deliveryplace  = ISNULL(RTRIM(deliveryplace),'')    
			   , @c_Type           = ISNULL(RTRIM(type),'')             
			   , @c_Door           = ISNULL(RTRIM(door),'')             
			   , @c_Stop           = ISNULL(RTRIM(stop),'')             
			   , @c_Route          = ISNULL(RTRIM(route),'')            
			   , @n_weight         = ISNULL(weight,0)           
			   , @n_cube           = ISNULL(cube,0)             
			   , @c_status         = ISNULL(RTRIM(status),'')           
			   , @n_casecnt        = ISNULL(casecnt,0)           
			   , @n_noofordlines   = ISNULL(noofordlines,0)      
			   , @c_rdd            = ISNULL(RTRIM(rdd),'')              
			   , @c_userdefine01   = ISNULL(RTRIM(userdefine01),'')     
			   , @c_userdefine02   = ISNULL(RTRIM(userdefine02),'')     
			   , @c_userdefine03   = ISNULL(RTRIM(userdefine03),'')     
			   , @c_userdefine04   = ISNULL(RTRIM(userdefine04),'')     
			   , @c_userdefine05   = ISNULL(RTRIM(userdefine05),'')     
			   , @dt_userdefine06  = userdefine06     
			   , @dt_userdefine07  = userdefine07     
			   , @c_userdefine08   = ISNULL(RTRIM(userdefine08),'')     
			   , @c_userdefine09   = ISNULL(RTRIM(userdefine09),'')     
			   , @c_userdefine10   = ISNULL(RTRIM(userdefine10),'')	    
   FROM LOADPLANDETAIL WITH (NOLOCK)       
   WHERE LoadKey = @c_LoadKey              
   AND   LoadLineNumber = @c_LoadlineNumber
   
   --NJOW01
   IF @@ROWCOUNT = 0
   BEGIN   	 
   	 SET @n_continue = 4
     GOTO QUIT
   END     

   IF ISNULL(RTRIM(@c_ToLoadKey),'') = ''
   BEGIN
      EXECUTE nspg_GetKey
       'LoadKey'
      ,10 
      ,@c_ToLoadKey  OUTPUT 
      ,@b_success   	OUTPUT 
      ,@n_err       	OUTPUT 
      ,@c_errmsg    	OUTPUT

      IF NOT @b_success = 1
      BEGIN
         SET @n_continue = 3
         SET @n_err = 30100
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Getting New loadkey. (isp_MoveOrderToLoad)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT
      END   
      SET @n_createnew = 1
   END 

   BEGIN TRAN
   DELETE LOADPLANDETAIL  
   WHERE LoadKey = @c_LoadKey
   AND   LoadLineNumber = @c_LoadlineNumber

   SET @n_err = @@ERROR
	 IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30101  
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Delete LOADPLANDETAIL. (isp_MoveOrderToLoad)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END

   IF @n_createnew = 1
   BEGIN
      INSERT INTO LOADPLAN (Facility, Loadkey)
		  VALUES (@c_facility, @c_ToLoadKey)

      SET @n_err = @@ERROR
   	  IF @n_err <> 0
      BEGIN
         SET @n_continue = 3
         SET @n_err = 30102  
         SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert LOADPLAN Table. (isp_MoveOrderToLoad)' 
                       + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
         GOTO QUIT
      END

      SET @c_toloadlinenumber = '00001'
   END
   ELSE
   BEGIN
      SELECT @c_toloadlinenumber = CONVERT(VARCHAR(5),ISNULL(MAX(CONVERT(INT,loadlinenumber)),0) + 1)
      FROM LOADPLANDETAIL WITH (NOLOCK)
      WHERE LoadKey = @c_ToLoadKey

      SET @c_toloadlinenumber = RIGHT('00000' + @c_toloadlinenumber,5)
   END
   
   INSERT INTO LOADPLANDETAIL (Loadkey, loadlinenumber, orderkey, externorderkey, consigneekey, customername,
	                             priority, orderdate, deliverydate, deliveryplace, 
										           Type, door, Stop, route, status, rdd, 
										           weight, cube, casecnt, noofordlines, 
										           userdefine01, userdefine02, userdefine03, userdefine04, userdefine05, 
										           userdefine06, userdefine07, userdefine08, userdefine09, userdefine10)
	                     VALUES (@c_ToLoadKey, @c_toloadlinenumber, @c_orderkey, @c_externorderkey, @c_consigneekey, @c_customername, 
	                     		     @c_priority, @dt_orderdate, @dt_deliverydate, @c_deliveryplace, 
	                     		     @c_Type, @c_door, @c_Stop, @c_route, @c_status, @c_rdd, 
	                     		     @n_weight, @n_cube, @n_casecnt, @n_noofordlines, 
	                             @c_userdefine01, @c_userdefine02, @c_userdefine03, @c_userdefine04, @c_userdefine05, 
	                     		     @dt_userdefine06, @dt_userdefine07, @c_userdefine08, @c_userdefine09, @c_userdefine10)

   SET @n_err = @@ERROR
	 IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30103  
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert LOADPLANDETAIL Table. (isp_MoveOrderToLoad)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END

   UPDATE LOADPLAN
   SET EditWho = SUSER_NAME()
      ,EditDate = GETDATE()
   WHERE LoadKey = @c_ToLoadKey

   SET @n_err = @@ERROR
	IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30104  
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update LoadPlan Table. (isp_MoveOrderToLoad)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END


   UPDATE ORDERDETAIL WITH (ROWLOCK)
   SET   LoadKey = @c_ToLoadKey
	      ,EditWho = SUSER_NAME()
	      ,EditDate= GETDATE()
	      ,Trafficcop = NULL			
   WHERE Orderkey = @c_orderkey

   SET @n_err = @@ERROR
	 IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30105 
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update ORDERDETAIL Table. (isp_MoveOrderToLoad)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END

   --NJOW01 Start   
   --RDT Sorting can pack multiple orders from multiple load with same consignee into a carton, the carton labelno will store in pickdetail.dropid.
   --move/merge multiple load can auto combine the carton from multiple load of same labelno. it only work for conso packing and same sku cannot have more than one line in a carton(packdetail)
   --expect to move the whole load plan. if move by order, all orders of a carton must move to a load, cannot move part of the orders of a carton.
   
   SELECT TOP 1 @c_FromPickslipNo = PKH.PickslipNo,
                @c_refkeylkup = CASE WHEN ISNULL(RL.Pickdetailkey,'') <> '' THEN 'Y' ELSE 'N' END
   FROM PACKHEADER PKH (NOLOCK) 
   JOIN PACKDETAIL PD (NOLOCK) ON PKH.Pickslipno = PD.Pickslipno
   JOIN PICKDETAIL PIK (NOLOCK) ON PD.LabelNo = PIK.DropID 
   LEFT JOIN REFKEYLOOKUP RL (NOLOCK) ON PKH.Pickslipno = RL.Pickslipno
   WHERE PKH.Loadkey = @c_Loadkey
   AND PIK.Orderkey = @c_Orderkey
   AND ISNULL(PKH.Orderkey,'') = ''

   IF ISNULL(@c_FromPickSlipNo,'') <> ''  --Conso packing exist with lableno = dropid
   BEGIN
      IF @n_createnew <> 1 --move to existing load
      BEGIN
      	 SELECT @c_ToPickslipno = Pickheaderkey
      	 FROM PICKHEADER (NOLOCK)
      	 WHERE Externorderkey = @c_ToLoadkey
      	 AND ISNULL(Orderkey,'') = ''
      END	 
     
      --Create new conso picklsip
      IF ISNULL(@c_ToPickslipno,'') = '' --create new or to exising load no conso pickslip
      BEGIN
         EXECUTE dbo.nspg_GetKey   
         'PICKSLIP',   9,   @c_ToPickslipno OUTPUT,   @b_Success OUTPUT,   @n_Err OUTPUT,   @c_Errmsg OUTPUT      
         
         IF @b_success <> 1
         BEGIN
            SET @n_continue = 3
            SET @n_err = 30106 
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Getkey(PICKSLIP). (isp_MoveOrderToLoad)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
         SELECT @c_ToPickslipno = 'P'+@c_ToPickslipno      

         IF EXISTS (SELECT 1 FROM PICKHEADER(NOLOCK) WHERE Pickheaderkey = @c_FromPickslipno)
         BEGIN
            INSERT INTO PICKHEADER (PickHeaderKey, Wavekey, ExternOrderKey, Orderkey, PickType, Zone, Storerkey, ConsoOrderkey, Loadkey, Consigneekey, Type, Priority, Status)  
                            SELECT @c_ToPickslipno, Wavekey, @c_ToLoadkey, Orderkey, Picktype, Zone, storerkey, consoOrderkey, Loadkey, Consigneekey, Type, Priority, Status
                            FROM PICKHEADER (NOLOCK)
                            WHERE Pickheaderkey = @c_FromPickslipno
         END
         ELSE
         BEGIN
            INSERT INTO PICKHEADER (PickHeaderKey, ExternOrderKey, PickType, Zone)  
            VALUES (@c_ToPickslipno, @c_ToLoadkey, '0', '7')
         END
         
         SET @n_err = @@ERROR
         IF @n_err <> 0
         BEGIN
            SET @n_continue = 3
            SET @n_err = 30107 
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert Pickheader Table. (isp_MoveOrderToLoad)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END         
         
         --creack conso pack header
         IF NOT EXISTS (SELECT 1 FROM PACKHEADER (NOLOCK) WHERE Pickslipno = @c_ToPickslipno)
	       BEGIN
            INSERT INTO PACKHEADER (Route, OrderKey, OrderRefNo, Loadkey, Consigneekey, StorerKey, PickSlipNo, Status, ConsoOrderkey)      
                   SELECT PH.Route, PH.Orderkey, PH.OrderRefNo, @c_ToLoadkey, '', PH.Storerkey, @c_ToPickslipno, PH.Status, PH.ConsoOrderkey
                   FROM  PACKHEADER PH (NOLOCK)      
                   WHERE PH.Pickslipno = @c_FromPickSlipNo
            
            SET @n_err = @@ERROR
            
            IF @n_err <> 0
            BEGIN

               SET @n_continue = 3
               SET @n_err = 30108 
               SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert Packheader Table. (isp_MoveOrderToLoad)' 
                             + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
               GOTO QUIT
            END
	       END
      END         
      
      --update refkeylookup   
      IF @c_refkeylkup = 'Y' 
      BEGIN
         UPDATE REFKEYLOOKUP WITH (ROWLOCK)
         SET PickslipNo = @c_ToPickslipno
             ,Loadkey = @c_ToLoadkey
         WHERE Orderkey = @c_Orderkey
         AND Pickslipno = @c_FromPickslipno

         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3  
            SET @n_err = 30109 
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Insert RefKeyLookup Table. (isp_MoveOrderToLoad)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
      END
      
      --update pickdetail to new pickslipno
      IF EXISTS (SELECT 1 FROM PICKDETAIL(NOLOCK) WHERE Pickslipno = @c_FromPickslipno AND Orderkey = @c_Orderkey)
      BEGIN
         UPDATE PICKDETAIL WITH (ROWLOCK) 
         SET Pickslipno = @c_ToPickslipno
             ,Trafficcop = NULL
         WHERE Orderkey = @c_Orderkey
         AND PickslipNo = @c_FromPickslipno

         SET @n_err = @@ERROR
         
         IF @n_err <> 0
         BEGIN
            SELECT @n_continue = 3  
            SET @n_err = 30110 
            SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update Pickdetail Table. (isp_MoveOrderToLoad)' 
                          + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
            GOTO QUIT
         END
      END
      
      --get last carton of the to pickslip
      SELECT @n_LastCartonNo = MAX(CartonNo)
      FROM PACKDETAIL(NOLOCK)
      WHERE Pickslipno = @c_ToPickslipno
      
      IF ISNULL(@n_LastCartonNo,0) = 0
         SET @n_LastCartonNo = 0               
      
      --move packdetail to new load(conso pack)
    	DECLARE CUR_ORD CURSOR  FAST_FORWARD READ_ONLY FOR
    	   SELECT PD.DropID, PD.Storerkey, PD.Sku, 
    	          SUM(PD.Qty) AS Qty
    	   FROM PICKDETAIL PD (NOLOCK)
    	   JOIN SKU (NOLOCK) ON PD.Storerkey = SKU.Storerkey AND PD.Sku = SKU.Sku 
    	   WHERE PD.Orderkey = @c_Orderkey
    	   GROUP BY PD.DropID, PD.Storerkey, PD.Sku
    	   ORDER BY PD.DropID
    	   
	    OPEN CUR_ORD

      SELECT @c_PrevDropID = '*'
	    FETCH NEXT FROM CUR_ORD INTO @c_DropID, @c_Storerkey, @c_sku, @n_Qty
	    WHILE @@FETCH_STATUS <> -1
	    BEGIN	    	
	    	 IF @c_Dropid <> @c_PrevDropID
	    	 BEGIN
	    	 	  SELECT @n_CartonNo = 0, @c_LabelLine = '', @n_FromCartonno = 0
    	      SELECT @n_CartonNo = MAX(CartonNo), @c_LabelLine = MAX(LabelLine) --get to-carton# of same label# and last label line no
    	      FROM PACKDETAIL(NOLOCK) 
    	      WHERE Pickslipno = @c_ToPickslipno 
    	      AND LabelNo = @c_DropId
    	      
    	      IF ISNULL(@n_CartonNo,0) = 0  
    	      BEGIN
    	      	 --assign new to-carton# if same lable# not found
    	      	 SET @n_LastCartonNo = @n_LastCartonNo + 1
    	         SET @n_CartonNo = @n_LastCartonNo
    	         SET @c_LabelLine = '00000'
    	      END    	          	      
    	      
    	      --get from carton no  	       
 	    	    SELECT TOP 1 @n_FromCartonno = Cartonno
	    	    FROM PACKDETAIL(NOLOCK) 
	    	    WHERE Pickslipno = @c_FromPickslipno
	    	    AND Labelno = @c_DropID	    	    
	    	 END
	    		    	 
	    	 IF EXISTS (SELECT 1 FROM PACKDETAIL(NOLOCK) 
	    	            WHERE Pickslipno = @c_ToPickslipno
	    	            AND Labelno = @c_DropID
	    	            AND Sku = @c_Sku)
	    	 BEGIN
	    	 	  --merge same carton of the same sku from different order/load
	    	    UPDATE PACKDETAIL WITH (ROWLOCK)
	    	    SET Qty = Qty + @n_Qty
	          WHERE Pickslipno = @c_ToPickslipno
	    	    AND Labelno = @c_DropID
	    	    AND Sku = @c_Sku	    	    
	    	 END          
	    	 ELSE
	    	 BEGIN
	    	 	  --move sku of the carton to new load(conso pack)
	    	 	  SET @c_LabelLine = RIGHT('00000' + RTRIM(LTRIM(CAST(CAST(@c_LabelLine AS INT) + 1 AS NVARCHAR))),5)
	    	 	  
	    	 	  INSERT INTO PACKDETAIL (Pickslipno, CartonNo, LabelNo, LabelLine, Storerkey, Sku, Qty, DropId, Refno, Refno2, UPC, ExpQty)
	    	 	     SELECT TOP 1 @c_ToPickslipno, @n_CartonNo, LabelNo, @c_LabelLine, Storerkey, Sku, @n_Qty, DropId, Refno, Refno2, UPC, ExpQty
	    	 	     FROM PACKDETAIL (NOLOCK)
    	         WHERE Pickslipno = @c_FromPickslipno
	    	       AND Labelno = @c_DropID
	    	       AND Sku = @c_Sku	    	 	  	    	 	  	    	 	  
	    	 END
	    	 
	    	 --deduct qty from old packing  
	    	 UPDATE PACKDETAIL WITH (ROWLOCK)
	    	 SET Qty = Qty - @n_Qty
	       WHERE Pickslipno = @c_FromPickslipno
	    	 AND Labelno = @c_DropID
	    	 AND Sku = @c_Sku	    	    	    	    

         --remove completed move sku from old pack. 
         --sometime one carton might contain a sku from more than one order of same load, it can move by order. last move have to delete the packdetail 
	    	 DELETE FROM PACKDETAIL
	       WHERE Pickslipno = @c_FromPickslipno
	    	 AND Labelno = @c_DropID
	    	 AND Sku = @c_Sku
	    	 AND Qty <= 0	   
	    	 
  	     --move packing info of the carton to new load plan(conso pack)    	       
  	     SELECT @n_CtnQty = SUM(PACKDETAIL.Qty), 
  	            @n_CtnCube = SUM(PACKDETAIL.Qty * SKU.StdCube),
  	            @n_CtnWgt =  SUM(PACKDETAIL.Qty * SKU.StdGrossWgt)
  	     FROM PACKDETAIL (NOLOCK)
  	     JOIN SKU (NOLOCK) ON PACKDETAIL.Storerkey = SKU.Storerkey AND PACKDETAIL.Sku = SKU.Sku
  	     WHERE PACKDETAIL.Pickslipno = @c_ToPickslipno
  	     AND PACKDETAIL.CartonNo = @n_CartonNo
  	     
	    	 IF EXISTS (SELECT 1 FROM PACKINFO(NOLOCK) 
	    	    WHERE Pickslipno = @c_ToPickslipno AND CartonNo = @n_CartonNo)
	    	 BEGIN
  	        UPDATE PACKINFO WITH (ROWLOCK)                                                                                    
  	        SET PACKINFO.Cube = @n_CtnCube,
               PACKINFO.Qty = @n_CtnQty
               --PACKINFO.Weight = @n_CtnWgt,     -- CM01
            WHERE PACKINFO.Pickslipno = @c_ToPickslipno 
            AND PACKINFO.CartonNo = @n_CartonNo
	    	 END	    	    
	    	 
	    	 IF EXISTS (SELECT 1 FROM PACKINFO(NOLOCK) 
	    	            WHERE Pickslipno = @c_FromPickslipno AND CartonNo = @n_FromCartonNo)
	    	 BEGIN
	    	    IF NOT EXISTS(SELECT 1 FROM PACKINFO(NOLOCK) WHERE Pickslipno = @c_ToPickslipno AND CartonNo = @n_Cartonno)
	    	    BEGIN                    	    	    
	    	 	 	  --move packing info to new load(conso pack)	    	    	 	  	    	    	 	  
	    	 	    UPDATE PACKINFO WITH (ROWLOCK)
	    	 	    SET Pickslipno = @c_ToPickslipno,
	    	 	        Cartonno = @n_Cartonno,
	    	 	        --Weight = @n_CtnWgt,	-- CM01
	    	 	        Cube = @n_CtnCube,
	    	 	        Qty = @n_CtnQty
	    	 	    WHERE Pickslipno = @c_FromPickslipno
	    	 	    AND Cartonno = @n_FromCartonno
	    	 	 END
	    	 	 ELSE
	    	 	 BEGIN
	    	 	 	  --remove packing info from old packing  	              
  	           DELETE FROM PACKINFO 
  	           WHERE Pickslipno = @c_FromPickslipno
  	           AND CartonNo = @n_FromCartonno
	    	 	 END
	    	 END
 	 	    	 	    	 	    
	    	 SET @c_PrevDropID = @c_DropID
   	     FETCH NEXT FROM CUR_ORD INTO @c_DropID, @c_Storerkey, @c_sku, @n_Qty
	    END
	    CLOSE CUR_ORD
    	DEALLOCATE CUR_ORD                                                           
   END
   --NJOW01 End

   UPDATE PACKHEADER WITH (ROWLOCK)
   SET   LoadKey = @c_ToLoadKey
	   ,  EditWho = SUSER_NAME()
	   ,  EditDate= GETDATE()
   WHERE Orderkey = @c_orderkey
   AND   LoadKey  = @c_LoadKey

   SET @n_err = @@ERROR
	 IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30106
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update PACKHEADER Table. (isp_MoveOrderToLoad)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END
      
   UPDATE MBOLDETAIL WITH (ROWLOCK)
   SET   LoadKey = @c_ToLoadKey
	   ,  EditWho = SUSER_NAME()
	   ,  EditDate= GETDATE()
	   ,  Trafficcop = NULL			
   WHERE Orderkey = @c_orderkey
   AND   LoadKey  = @c_LoadKey

   SET @n_err = @@ERROR
	IF @n_err <> 0
   BEGIN
      SET @n_continue = 3
      SET @n_err = 30107
      SET @c_errmsg = 'NSQL'+CONVERT(char(5),@n_err)+': Error Update MBOLDETAIL Table. (isp_MoveOrderToLoad)' 
                    + ' ( ' + ' SQLSvr MESSAGE=' + ISNULL(RTRIM(@c_errmsg),'') + ' ) ' 
      GOTO QUIT
   END

   QUIT:
   IF @n_continue=3  -- Error Occured - Process And Return
   BEGIN
      SET @b_success = 0
      IF @@TRANCOUNT = 1 and @@TRANCOUNT > @n_starttcnt
      BEGIN
         ROLLBACK TRAN
      END
      ELSE
      BEGIN
         WHILE @@TRANCOUNT > @n_starttcnt
         BEGIN
            COMMIT TRAN
         END
      END
      execute nsp_logerror @n_err, @c_errmsg, 'isp_MoveOrderToLoad'
      RAISERROR (@c_errmsg, 16, 1) WITH SETERROR    -- SQL2012
      RETURN
   END
	ELSE
   BEGIN
      SET @b_success = 1
      WHILE @@TRANCOUNT > @n_starttcnt
      BEGIN
       COMMIT TRAN
      END
      RETURN
   END	   
END 

GO