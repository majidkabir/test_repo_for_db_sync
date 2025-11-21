SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/************************************************************************/
/* Store procedure: rdt_1642ExtValT                                     */
/*                                                                      */
/* Purpose: Display final location                                      */
/*                                                                      */
/* Date       Rev  Author   Purposes                                    */
/* 2015-07-13 1.0  PPA374   Checks that place of loading is a door      */
/* 2024-05-28 1.1  TAK047   Add Storerkey as condition (CLVN01)         */
/* 2024-06-26 1.2  AGA399   Add Load Sequence as condition              */
/************************************************************************/

CREATE   PROCEDURE [RDT].[rdt_1642ExtValVLT] (
@nMobile      INT,
@nFunc        INT,
@cLangCode    NVARCHAR( 3),
@nStep        INT,
@nInputKey    INT,
@cDropID      NVARCHAR( 20),
@cMbolKey     NVARCHAR( 10),
@cDoor        NVARCHAR( 20),
@cOption      NVARCHAR( 1),
@cRSNCode     NVARCHAR( 10),
@nAfterStep   INT,
@nErrNo       INT OUTPUT,
@cErrMsg      NVARCHAR( 20) OUTPUT
) AS
BEGIN
SET NOCOUNT ON
SET QUOTED_IDENTIFIER OFF
SET ANSI_NULLS OFF
SET CONCAT_NULL_YIELDS_NULL OFF

DECLARE
@Orderkey nvarchar(20),
@FullyPicked int,
@AtStage int,
@FullyPacked int,
@OrderGroup nvarchar(20),--AGA399
@IntOrderGroup int,
@hasSequeceConfig int,
@waveFirstOrderGroup int,
@currentLoadValue int,
@loadSequenceOk int,
@nOfSoDropId int,
@nOfDropIdLoaded int,
@GotSequence nvarchar(10),
@GotNOSequence nvarchar(10),
@DropIDSequence nvarchar(10),
@NextSequence nvarchar(10),
@Storerkey nvarchar(20),
@Facility nvarchar(20)

select top 1 @Storerkey = storerkey from rdt.RDTMOBREC (NOLOCK) where Mobile = @nMobile
select top 1 @Facility = Facility from rdt.RDTMOBREC (NOLOCK) where Mobile = @nMobile

IF @nFunc = 1642 and @nStep = 1 and @nInputKey = 1
   IF isnull(@cDropID,'') <> ''
   BEGIN
      select top 1 @Orderkey = OrderKey from PICKHEADER (NOLOCK) where PickHeaderKey = (select top 1 PickSlipNo from PackDetail (NOLOCK) where storerkey = @Storerkey and dropid = @cDropID) --(CLVN01)
	  set @FullyPicked = case when (select sum(openqty)-sum(QtyPicked) from ORDERDETAIL (NOLOCK) where OrderKey = @Orderkey and StorerKey = @Storerkey) = 0 then 1 else 0 end
	  select top 1 @DropIDSequence = OrderGroup from ORDERS (NOLOCK) where OrderKey = @Orderkey and StorerKey = @Storerkey

      SET @AtStage = case when exists(
      select Loc from PICKDETAIL PD (NOLOCK)
	  where orderkey = @Orderkey
	  and Storerkey = @Storerkey
	  and loc not in
	  (select OtherReference from MBOL (NOLOCK)
	  where Facility = @Facility
	  and mbolkey = 
	  (select top 1 mbolkey from orders (NOLOCK) where orderkey = @Orderkey and Storerkey = @Storerkey))) then 0 else 1 end

	  set @FullyPacked = case when
	  (select isnull(sum(openqty),0) from ORDERDETAIL (NOLOCK) where OrderKey = @Orderkey and StorerKey = @Storerkey)
	  =
	  (select isnull(sum(qty),0) from PackDetail (NOLOCK)
	  where StorerKey = @Storerkey
	  and PickSlipNo = 
	  (select top 1 PickSlipNo from PackDetail (NOLOCK) where storerkey = @Storerkey and dropid = @cDropID)) --(CLVN01)
	  then 1 else 0 end

      SET @GotSequence = case when exists
	  (
	  select OrderGroup from ORDERS (NOLOCK)
	  where StorerKey = @Storerkey
	  and orderkey in
	  (select OrderKey from WAVEDETAIL (NOLOCK)
	  where WaveKey in
	  (select top 1 wd.WaveKey from WAVEDETAIL WD (NOLOCK)
	  join Orders O (NOLOCK)
	  on O.OrderKey = WD.OrderKey
	  join PICKDETAIL PID (NOLOCK)
	  on PID.OrderKey = O.OrderKey
	  join PackDetail PAD (NOLOCK)
	  on PID.dropid = PAD.RefNo2
	  where PAD.DropID = @cDropID
	  and O.Storerkey = @Storerkey)
	  and isnumeric(OrderGroup)=1)
	  ) then 1 else 0 end

	  SET @GotNOSequence = case when exists
	  (
	  select OrderGroup from ORDERS (NOLOCK)
	  where StorerKey = @Storerkey
	  and orderkey in
	  (select OrderKey from WAVEDETAIL (NOLOCK)
	  where WaveKey in
	  (select top 1 wd.WaveKey from WAVEDETAIL WD (NOLOCK)
	  join Orders O (NOLOCK)
	  on O.OrderKey = WD.OrderKey
	  join PICKDETAIL PID (NOLOCK)
	  on PID.OrderKey = O.OrderKey
	  join PackDetail PAD (NOLOCK)
	  on PID.dropid = PAD.RefNo2
	  where PAD.DropID = @cDropID
	  and O.Storerkey = @Storerkey)
	  and isnumeric(OrderGroup)=0)
	  ) then 1 else 0 end

	  IF exists
	  (select OrderGroup from ORDERS (NOLOCK)
	  where StorerKey = @Storerkey 
	  and orderkey in
	  (select OrderKey from WAVEDETAIL (NOLOCK)
	  where WaveKey in
	  (select top 1 wd.WaveKey from WAVEDETAIL WD (NOLOCK)
	  join Orders O (NOLOCK)
	  on O.OrderKey = WD.OrderKey
	  join PICKDETAIL PID (NOLOCK)
	  on PID.OrderKey = O.OrderKey
	  join PackDetail PAD (NOLOCK)
	  on PID.dropid = PAD.RefNo2
	  where PAD.DropID = @cDropID
	  and O.Storerkey = @Storerkey)
	  and isnumeric(OrderGroup)=0
	  and isnull(OrderGroup,'') <> ''))
	  BEGIN
         set @nErrNo = 217992
		 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Non-numeric sequence
		 GOTO Quit
	  END

	  select top 1 @NextSequence = OrderGroup from ORDERS (NOLOCK)
	  where StorerKey = @Storerkey 
	  and orderkey in
	  (select OrderKey from WAVEDETAIL (NOLOCK)
	  where WaveKey in
	  (select top 1 wd.WaveKey from WAVEDETAIL WD (NOLOCK)
	  join Orders O (NOLOCK)
	  on O.OrderKey = WD.OrderKey
	  join PICKDETAIL PID (NOLOCK)
	  on PID.OrderKey = O.OrderKey
	  join PackDetail PAD (NOLOCK)
	  on PID.dropid = PAD.RefNo2
	  where PAD.DropID = @cDropID
	  and O.Storerkey = @Storerkey)
	  and status <8)
	  order by OrderGroup

	  IF @GotSequence = 1 and @GotNOSequence = 1
	  BEGIN
         set @nErrNo = 217993
		 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Missing sequence
		 GOTO Quit
	  END

	  IF @GotNOSequence = 1
	  BEGIN
		 set @loadSequenceOk = 1
		 GOTO skip1
	  END

	  IF exists 
	  (select CASE WHEN COUNT(*) > 1 THEN 1 ELSE 0 END  from ORDERS (NOLOCK)
	  where StorerKey = @Storerkey 
	  and orderkey in
	  (select OrderKey from WAVEDETAIL (NOLOCK)
	  where WaveKey in
	  (select top 1 wd.WaveKey from WAVEDETAIL WD (NOLOCK)
	  join Orders O (NOLOCK)
	  on O.OrderKey = WD.OrderKey
	  join PICKDETAIL PID (NOLOCK)
	  on PID.OrderKey = O.OrderKey
	  join PackDetail PAD (NOLOCK)
	  on PID.dropid = PAD.RefNo2
	  where PAD.DropID = @cDropID
	  and O.Storerkey = @Storerkey)
	  and isnumeric(OrderGroup)=1)
	  group by OrderGroup
	  having CASE WHEN COUNT(*) > 1 THEN 1 ELSE 0 END >0)
	  BEGIN
		 set @nErrNo = 217994
		 SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Duplicated sequence
		 GOTO Quit
	  END

	  IF @DropIDSequence <> @NextSequence
	  BEGIN
		 SET @loadSequenceOk = 0
      END

      skip1:
      IF @nStep = 1 and (select top 1 LocationType from loc (NOLOCK) where loc = @cDoor and Facility = @Facility) <> 'DOOR'
      BEGIN
	     SET @nErrNo = 217995
	     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Loc is not a door
      END

      ELSE IF @nStep = 1 and @FullyPicked = 0
      BEGIN
	     SET @nErrNo = 217996
	     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not all items picked
      END

      ELSE IF @nStep = 1 and @AtStage = 0
      BEGIN
	     SET @nErrNo = 217997
	     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not fully staged
      END

      ELSE IF @nStep = 1 and @FullyPacked = 0 
      and (1 in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQPCKALL' and Storerkey = @Storerkey) 
      and 0 not in (select short from CODELKUP (NOLOCK) where LISTNAME = 'HUSQPCKALL' and Storerkey = @Storerkey))
      BEGIN
	     SET @nErrNo = 217998
	     SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Not all items packed
      END

   --Error mesg in case Load sequence is not correct
   IF @nStep = 1 and @loadSequenceOk = 0 
   BEGIN
      SET @nErrNo = 217999
	  SET @cErrMsg = rdt.rdtgetmessage( @nErrNo, @cLangCode, 'DSP') --Out of Sequence
   END

  Quit:

END
END

GO